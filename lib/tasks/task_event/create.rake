namespace :task_event do
  namespace :create_send_notice do
    desc '今日が期間内のタスクイベント作成＋当日通知（通知は開始時間以降）'
    task(:today, [:dry_run] => :environment) do |_, args|
      Rake::Task['task_event:create_send_notice'].invoke(Time.current.to_date, args.dry_run, 'today', 'true')
    end

    desc '翌営業日が期間内のタスクイベント作成＋事前通知（作成・通知は開始時間以降）'
    task(:next, [:dry_run] => :environment) do |_, args|
      Rake::Task['task_event:create_send_notice'].invoke(Time.current.to_date, args.dry_run, 'next', 'true')
    end
  end

  desc '対象日が期間内のタスクイベント作成＋通知（当日に実行できなかった場合に手動実行）'
  task(:create_send_notice, %i[target_date dry_run notice_target send_notice] => :environment) do |task, args|
    include ERB::Util
    include TaskCyclesConcern
    @months = nil

    begin
      target_date = args.target_date&.to_date
      raise '日付が指定されていません。' if target_date.blank?
      raise '翌々日以降の日付は指定できません。' if target_date > Time.current.to_date.tomorrow
    rescue StandardError
      raise '日付の形式が不正です。'
    end
    args.with_defaults(dry_run: 'true', send_notice: 'false')
    dry_run = (args.dry_run != 'false')
    notice_target = args.notice_target&.to_sym || :blank
    send_notice = args.send_notice == 'true'

    @logger = new_logger(task.name)
    @logger.info("=== START #{task.name} ===")
    @logger.info("#{notice_target}, target_date: #{target_date}, dry_run: #{dry_run}, send_notice: #{send_notice}")

    total_insert_count = 0
    total_notice_success_count = 0
    total_notice_failure_count = 0
    ActiveRecord::Base.connection_pool.with_connection do # NOTE: 念の為（PG::UnableToSend: no connection to the server対策）
      set_holidays(target_date, target_date + 1.month) # NOTE: 1ヶ月以上の休みはない前提
      business_date = handling_holiday_date(target_date, :after)
      if business_date != target_date # NOTE: 休日は作成・通知しない
        @logger.info("business_date: #{business_date} ...Skip")
        next
      end

      next_business_date = handling_holiday_date(target_date.tomorrow, :after)
      next_start_date = notice_target == :next ? next_business_date : target_date
      start_date = target_date - 31.days # NOTE: 期間が20営業日でも1ヶ月を超える場合がある為
      end_date = target_date + 31.days
      set_holidays(start_date, end_date)
      @logger.info("next_business_date: #{next_business_date}, next_start_date: #{next_start_date}, start_date: #{start_date}, end_date: #{end_date}")

      spaces = Space.active.eager_load(:task_send_setting_active).order(:process_priority, :id).merge(TaskSendSetting.order(updated_at: :desc, id: :desc))
      count = spaces.count
      spaces.each.with_index(1) do |space, index|
        logger_message = nil
        task_send_setting = %i[today next].include?(notice_target) ? space.task_send_setting_active.first : nil
        if notice_target == :next
          next_notice_start = task_send_setting&.next_notice_start_hour || Settings.default_next_notice_start_hour
          logger_message = ", next_notice_start: #{next_notice_start}#{'(default)' if task_send_setting.blank?}"
          if target_date + next_notice_start.hours > Time.current # NOTE: [事前通知]開始時間以降に作成
            @logger.info("[#{index}/#{count}] space.id: #{space.id}#{logger_message} ...Skip")
            next
          end
        end

        # タスクイベント作成
        @logger.info("[#{index}/#{count}] space.id: #{space.id}#{logger_message}")
        total_insert_count += create_task_events(dry_run, space, next_business_date, next_start_date, start_date, end_date)

        next if !send_notice || task_send_setting.blank? || (!task_send_setting.slack_enabled && !task_send_setting.email_enabled)

        # タスクイベント通知
        if notice_target == :today
          today_notice_start = task_send_setting.today_notice_start_hour
          @logger.info("today_notice_start: #{today_notice_start}")
          next if target_date + today_notice_start.hours > Time.current # NOTE: [当日通知]開始時間以降に通知
        end

        success_count, failure_count = send_notice_task_events(dry_run, notice_target, space, task_send_setting, target_date)
        total_notice_success_count += success_count
        total_notice_failure_count += failure_count
      end
    end

    @logger.info("Total insert: #{total_insert_count}, notice_success: #{total_notice_success_count}, notice_failure: #{total_notice_failure_count}")
    @logger.info("=== END #{task.name} ===")
  end

  # タスクイベント作成
  def create_task_events(dry_run, space, next_business_date, next_start_date, start_date, end_date)
    task_cycles = TaskCycle.active.where(space: space).by_month(cycle_months(start_date, end_date) + [nil])
                           .eager_load(:task).by_task_period(next_start_date, next_start_date).merge(Task.order(:priority)).order(:id)
    @logger.info("task_cycles.count: #{task_cycles.count}")
    return 0 if task_cycles.count.zero?

    task_events = TaskEvent.where(space: space, started_date: start_date.., ended_date: ..next_business_date)
                           .eager_load(task_cycle: :task).merge(Task.order(:priority)).order(:id)
    @exist_task_events = task_events.map { |task_event| [{ task_cycle_id: task_event.task_cycle_id, ended_date: task_event.ended_date }, true] }.to_h
    @logger.debug("@exist_task_events: #{@exist_task_events}")

    @next_events = []
    task_cycles.each do |task_cycle|
      cycle_set_next_events(task_cycle, task_cycle.task, start_date, end_date)
    end
    insert_events = @next_events.filter { |_, event_start_date, event_end_date| event_start_date <= next_start_date && event_end_date >= next_start_date }
    @logger.info("insert: #{insert_events.count}")
    return 0 if insert_events.count.zero?

    index = -1
    codes = create_unique_codes(insert_events.count)
    now = Time.current
    insert_params = { space_id: space.id, created_at: now, updated_at: now }
    insert_datas = insert_events.map do |task_cycle, event_start_date, event_end_date|
      index += 1
      insert_params.merge(code: codes[index], task_cycle_id: task_cycle.id, started_date: event_start_date, ended_date: event_end_date)
    end
    @logger.debug("insert_datas: #{insert_datas}")
    TaskEvent.insert_all!(insert_datas) if !dry_run && insert_datas.present?

    insert_events.count
  end

  # ユニークコード作成
  def create_unique_codes(count)
    unique_codes = []
    try_count = 1
    loop do
      codes = (count - unique_codes.count).times.map { Digest::MD5.hexdigest(SecureRandom.uuid).to_i(16).to_s(36).rjust(25, '0') }
      unique_codes += codes - TaskEvent.where(code: codes).pluck(:code)
      return unique_codes if unique_codes.count >= count

      # :nocov:
      if try_count < 10
        @logger.warn("[WARN](#{try_count})Not unique code(#{codes})")
      elsif try_count >= 10
        message = "[ERROR](#{try_count})Not unique code(#{codes})"
        @logger.error(message)
        raise message
      end
      try_count += 1
      # :nocov:
    end
  end

  # タスクイベント通知
  def send_notice_task_events(dry_run, notice_target, space, task_send_setting, target_date)
    enable_send_target = get_enable_send_target(notice_target, space, task_send_setting, target_date)
    return 0, 0 unless enable_send_target.values.any?

    # REVIEW: dry_runでは今回作成分が対象にならない
    task_events = TaskEvent.where(space: space).where.not(status: %i[complete unnecessary])
                           .eager_load(task_cycle: :task).order(:status).merge(Task.order(:priority)).order(:id)
    notice_required = task_send_setting["#{notice_target}_notice_required"]
    return 0, 0 if !notice_required && task_events.count.zero?

    @next_task_events = {}
    @expired_task_events = {}
    @end_today_task_events = {}
    @date_include_task_events = {}
    task_events.each do |task_event|
      if task_event.started_date > target_date
        @next_task_events[task_event.id] = task_event if notice_target == :next
      elsif task_event.ended_date < target_date
        @expired_task_events[task_event.id] = task_event
      elsif task_event.ended_date == target_date
        @end_today_task_events[task_event.id] = task_event
      else
        @date_include_task_events[task_event.id] = task_event
      end
    end

    success_count = 0
    failure_count = 0
    history_params = task_send_history_params(space, task_send_setting, notice_target, target_date)
    TaskSendHistory.send_targets.each do |send_target, _|
      next unless enable_send_target[send_target]

      task_send_history = TaskSendHistory.new(history_params.merge(send_target: send_target, sended_at: Time.current))
      case send_target.to_sym
      when :slack
        task_send_history = send_notice_slack(dry_run, task_send_history)
      when :email
        task_send_history = send_notice_email(dry_run, task_send_history)
      else
        # :nocov:
        raise "send_target not found.(#{send_target})"
        # :nocov:
      end
      task_send_history.send_result.to_sym == :success ? success_count += 1 : failure_count += 1

      task_send_history.save! unless dry_run
    end

    @logger.info("notice_success: #{success_count}, notice_failure: #{failure_count}")
    [success_count, failure_count]
  end

  # 送信対象毎の通知有無 # NOTE: 最終送信結果が失敗の場合は再通知。他の送信対象に通知後に通知するに変更した送信対象には通知しない
  def get_enable_send_target(notice_target, space, task_send_setting, target_date)
    last_send_results = {}
    task_send_histories = TaskSendHistory.where(space: space, notice_target: notice_target, target_date: target_date).order(id: :desc)
    task_send_histories.each do |task_send_history|
      last_send_results[task_send_history.send_target] = task_send_history.send_result unless last_send_results.key?(task_send_history.send_target)
      break if TaskSendHistory.send_targets.keys - last_send_results.keys == []
    end
    @logger.debug("last_send_results: #{last_send_results}")

    enable_send_target = {}
    TaskSendHistory.send_targets.each do |send_target, _|
      enabled = task_send_setting["#{send_target}_enabled"]
      enabled = false if enabled && last_send_results.count.positive? && last_send_results[send_target]&.to_sym != :failure

      enable_send_target[send_target] = enabled
    end
    @logger.debug("enable_send_target: #{enable_send_target}")

    enable_send_target
  end

  def task_send_history_params(space, task_send_setting, notice_target, target_date)
    {
      space: space,
      task_send_setting: task_send_setting,
      notice_target: notice_target,
      target_date: target_date,
      next_task_event_ids: @next_task_events.keys,
      expired_task_event_ids: @expired_task_events.keys,
      end_today_task_event_ids: @end_today_task_events.keys,
      date_include_task_event_ids: @date_include_task_events.keys
    }
  end

  def send_notice_slack(dry_run, task_send_history)
    username = "#{I18n.t('app_name')}#{Settings.env_name}"
    default_mention = task_send_history.task_send_setting.slack_mention
    default_mention = "<#{html_escape(default_mention)}>" if default_mention.present?
    code = task_send_history.space.code
    notice_target = task_send_history.notice_target.to_sym
    sended_data = {
      text: "[#{I18n.t("notifier.task_event.notice_target.#{notice_target}")}] " +
            I18n.t('notifier.task_event.message', name: "<#{Settings.front_url}/-/#{code}|#{html_escape(task_send_history.space.name)}>"),
      attachments: [
        notice_target == :next ? slack_attachment(:next, @next_task_events, default_mention, code) : nil,
        slack_attachment(:expired, @expired_task_events, default_mention, code),
        slack_attachment(:end_today, @end_today_task_events, default_mention, code),
        slack_attachment(:date_include, @date_include_task_events, default_mention, code)
      ].compact
    }
    task_send_history.sended_data = sended_data.to_s
    begin
      notifier = Slack::Notifier.new(task_send_history.task_send_setting.slack_webhook_url, username: username, icon_emoji: ':alarm_clock:')
      notifier.post(sended_data) unless dry_run
      task_send_history.send_result = :success
    rescue StandardError => e
      task_send_history.send_result = :failure
      task_send_history.error_message = e.message
    end

    task_send_history
  end

  def slack_attachment(type, task_events, default_mention, code)
    text = ''
    task_events.each do |_, task_event|
      if task_event.assigned_user.blank?
        assigned_user = "#{I18n.t('notifier.task_event.assigned.notfound')} #{default_mention}"
      else
        assigned_user = html_escape(task_event.assigned_user.name) # TODO: メンション
      end
      url = "#{Settings.front_url}/-/#{code}?code=#{task_event.code}"
      priority = task_event.task_cycle.task.priority.to_sym == :none ? '' : "[#{task_event.task_cycle.task.priority_i18n}]"
      text += "#{slack_status_icon(type, task_event.status.to_sym, task_event.assigned_user)} [#{task_event.status_i18n}] #{assigned_user}\n" \
              "<#{url}|#{priority}#{html_escape(task_event.task_cycle.task.title)}>\n\n"
    end

    {
      title: I18n.t("notifier.task_event.type.#{type}.title"),
      color: I18n.t("notifier.task_event.type.#{type}.slack_color"),
      text: task_events.count.positive? ? text : I18n.t('notifier.task_event.list.notfound')
    }
  end

  def slack_status_icon(type, status, assigned_user)
    case type
    when :next
      ':alarm_clock:'
    when :expired
      ':red_circle:'
    when :end_today
      case status
      when :untreated, :waiting_premise, :confirmed_premise
        assigned_user.blank? ? ':warning:' : ':umbrella:'
      when :processing, :pending
        ':cloud:'
      when :waiting_confirm
        ':sunny:'
      else
        # :nocov:
        raise "type, status not found.(#{type}, #{status})"
        # :nocov:
      end
    when :date_include
      case status
      when :untreated, :waiting_premise, :confirmed_premise
        assigned_user.blank? ? ':warning:' : ':cloud:'
      when :processing, :waiting_confirm
        ':sunny:'
      when :pending
        ':cloud:'
      else
        # :nocov:
        raise "type, status not found.(#{type}, #{status})"
        # :nocov:
      end
    else
      # :nocov:
      raise "type not found.(#{type})"
      # :nocov:
    end
  end

  def send_notice_email(_dry_run, task_send_history)
    task_send_history.send_result = :failure

    # TODO: メール送信

    task_send_history
  end
end
