namespace :task_event do
  namespace :create_send_notice do
    desc '今日が期間内のタスクイベント作成＋開始確認を通知（通知は開始時間以降）'
    task(:start, [:dry_run] => :environment) do |_, args|
      Rake::Task['task_event:create_send_notice'].invoke(Time.current.to_date, args.dry_run, 'start', 'true')
    end

    desc '翌営業日が期間内のタスクイベント作成＋翌営業日・終了確認を通知（作成・通知は開始時間以降）'
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

      spaces = Space.active.eager_load(:send_setting_active).order(:process_priority, :id).merge(SendSetting.order(updated_at: :desc, id: :desc))
      count = spaces.count
      spaces.each.with_index(1) do |space, index|
        logger_message = nil
        send_setting = %i[start next].include?(notice_target) ? space.send_setting_active.first : nil
        if notice_target == :next
          next_notice_start = send_setting&.next_notice_start_hour || Settings.default_next_notice_start_hour
          logger_message = ", next_notice_start: #{next_notice_start}#{'(default)' if send_setting.blank?}"
          if target_date + next_notice_start.hours > Time.current # NOTE: [翌営業日・終了確認]開始時間以降に作成
            @logger.info("[#{index}/#{count}] space.id: #{space.id}#{logger_message} ...Skip")
            next
          end
        end

        # タスクイベント作成
        @logger.info("[#{index}/#{count}] space.id: #{space.id}#{logger_message}")
        total_insert_count += create_task_events(dry_run, space, next_start_date, start_date, end_date)

        next if !send_notice || send_setting.blank? || (!send_setting.slack_enabled && !send_setting.email_enabled)

        # タスクイベント通知
        if notice_target == :start
          start_notice_start = send_setting.start_notice_start_hour
          @logger.info("start_notice_start: #{start_notice_start}")
          next if target_date + start_notice_start.hours > Time.current # NOTE: [開始確認]開始時間以降に通知
        end

        success_count, failure_count = send_notice_task_events(dry_run, notice_target, space, send_setting, target_date)
        total_notice_success_count += success_count
        total_notice_failure_count += failure_count
      end
    end

    @logger.info("Total insert: #{total_insert_count}, notice_success: #{total_notice_success_count}, notice_failure: #{total_notice_failure_count}")
    @logger.info("=== END #{task.name} ===")
  end

  # タスクイベント作成
  def create_task_events(dry_run, space, next_start_date, start_date, end_date)
    task_cycles = TaskCycle.active.where(space: space).by_month(cycle_months(start_date, end_date) + [nil])
                           .eager_load(:task).by_task_period(next_start_date, next_start_date).merge(Task.order(:priority)).order(:id)
    @logger.info("task_cycles.count: #{task_cycles.count}")
    return 0 if task_cycles.count.zero?

    task_events = TaskEvent.where(space: space, started_date: start_date..)
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
  def send_notice_task_events(dry_run, notice_target, space, send_setting, target_date)
    enable_send_target = get_enable_send_target(notice_target, space, send_setting, target_date)
    return 0, 0 unless enable_send_target.values.any?

    # REVIEW: dry_runでは今回作成分が対象にならない
    @task_events = TaskEvent.where(space: space).where.not(status: %i[complete unnecessary])
                            .eager_load(task_cycle: :task).order(:status).merge(Task.order(:priority)).order(:id)
    set_data_task_events(notice_target, target_date, space.send_setting_active.first.slack_domain_id, enable_send_target['slack'])

    success_count = 0
    failure_count = 0
    history_params = send_history_params(space, send_setting, notice_target, target_date)
    space_url = "#{Settings.front_url}/-/#{space.code}"
    SendHistory.send_targets.each do |send_target, _|
      next unless enable_send_target[send_target]

      send_history = SendHistory.new(history_params.merge(send_target: send_target, started_at: Time.current))
      if !send_setting["#{notice_target}_notice_required"] && @task_events.count.zero?
        send_history.status = :skip
        send_history.completed_at = Time.current
        send_history.save! unless dry_run
        next
      end

      case send_target.to_sym
      when :slack
        send_history = send_notice_slack(dry_run, space, send_history, space_url)
        send_history.save! unless dry_run
      when :email
        send_history = send_notice_email(dry_run, space, send_history, space_url)
      else
        # :nocov:
        raise "send_target not found.(#{send_target})"
        # :nocov:
      end
      send_history.status.to_sym == :failure ? failure_count += 1 : success_count += 1
    end

    @logger.info("notice_success: #{success_count}, notice_failure: #{failure_count}")
    [success_count, failure_count]
  end

  # 送信対象毎の通知有無 # NOTE: 最終ステータスが失敗の場合は再通知。他の送信対象に通知後に通知するに変更した送信対象には通知しない
  def get_enable_send_target(notice_target, space, send_setting, target_date)
    last_statuss = {}
    send_histories = SendHistory.where(space: space, notice_target: notice_target, target_date: target_date).order(id: :desc)
    send_histories.each do |send_history|
      last_statuss[send_history.send_target] = send_history.status unless last_statuss.key?(send_history.send_target)
      break if SendHistory.send_targets.keys - last_statuss.keys == []
    end
    @logger.debug("last_statuss: #{last_statuss}")

    enable_send_target = {}
    SendHistory.send_targets.each do |send_target, _|
      enabled = send_setting["#{send_target}_enabled"]
      enabled = false if enabled && last_statuss.count.positive? && last_statuss[send_target]&.to_sym != :failure

      enable_send_target[send_target] = enabled
    end
    @logger.debug("enable_send_target: #{enable_send_target}")

    enable_send_target
  end

  def set_data_task_events(notice_target, target_date, slack_domain_id, enable_slack)
    @next_task_events = {}
    @expired_task_events = {}
    @end_today_task_events = {}
    @date_include_task_events = {}
    assigned_user_ids = {}
    @task_events.each do |task_event|
      if task_event.started_date > target_date
        @next_task_events[task_event.id] = task_event if notice_target == :next
      elsif task_event.ended_date < target_date
        @expired_task_events[task_event.id] = task_event
      elsif task_event.ended_date == target_date
        @end_today_task_events[task_event.id] = task_event
      else
        @date_include_task_events[task_event.id] = task_event
      end

      assigned_user_ids[task_event.assigned_user.id] = true if enable_slack && task_event.assigned_user.present?
    end
    if assigned_user_ids.present?
      @assigned_slack_users = SlackUser.where(slack_domain_id: slack_domain_id, user: assigned_user_ids.keys).index_by(&:user_id)
    else
      @assigned_slack_users = {}
    end
  end

  def send_history_params(space, send_setting, notice_target, target_date)
    {
      space: space,
      send_setting: send_setting,
      notice_target: notice_target,
      target_date: target_date,
      next_task_event_ids: @next_task_events.keys,
      expired_task_event_ids: @expired_task_events.keys,
      end_today_task_event_ids: @end_today_task_events.keys,
      date_include_task_event_ids: @date_include_task_events.keys
    }
  end

  def send_notice_slack(dry_run, space, send_history, space_url)
    default_mention = send_history.send_setting.slack_mention
    default_mention = "<#{html_escape(default_mention)}>" if default_mention.present?
    sended_data = {
      text: "[#{I18n.t("enums.send_history.notice_target.#{send_history.notice_target}")}] " +
            I18n.t('notifier.task_event.message', name: "<#{space_url}|#{html_escape(space.name)}>"),
      attachments: [
        send_history.notice_target.to_sym == :next ? slack_task_events(:next, @next_task_events, default_mention, space_url) : nil,
        slack_task_events(:expired, @expired_task_events, default_mention, space_url),
        slack_task_events(:end_today, @end_today_task_events, default_mention, space_url),
        slack_task_events(:date_include, @date_include_task_events, default_mention, space_url)
      ].compact
    }
    send_history.sended_data = sended_data.to_s
    begin
      slack_webhook_url = send_history.send_setting.slack_webhook_url
      notifier = Slack::Notifier.new(slack_webhook_url, username: "#{I18n.t('app_name')}#{Settings.env_name}", icon_emoji: ':alarm_clock:')
      notifier.post(sended_data) unless dry_run
      send_history.status = :success
    rescue StandardError => e
      send_history.status = :failure
      send_history.error_message = e.message
    end
    send_history.completed_at = Time.current

    send_history
  end

  def slack_task_events(type, task_events, default_mention, space_url)
    text = ''
    task_events.each do |_, task_event|
      if task_event.assigned_user.blank?
        assigned_user = "#{I18n.t('notifier.task_event.assigned.notfound')} #{default_mention}"
      else
        slack_user = @assigned_slack_users[task_event.assigned_user_id]
        assigned_user = slack_user.present? ? "<@#{html_escape(slack_user.memberid)}>" : html_escape(task_event.assigned_user.name)
      end
      priority = task_event.task_cycle.task.priority.to_sym == :none ? '' : "[#{task_event.task_cycle.task.priority_i18n}]"
      text += "#{slack_status_icon(type, task_event.status.to_sym, task_event.assigned_user)} [#{task_event.status_i18n}] #{assigned_user}\n" \
              "<#{space_url}?code=#{task_event.code}|#{priority}#{html_escape(task_event.task_cycle.task.title)}>\n\n"
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

  def send_notice_email(dry_run, space, send_history, space_url)
    unless dry_run
      NoticeMailer.with(
        space: space,
        send_history: send_history,
        space_url: space_url,
        next_task_events: @next_task_events.values,
        expired_task_events: @expired_task_events.values,
        end_today_task_events: @end_today_task_events.values,
        date_include_task_events: @date_include_task_events.values
      ).incomplete_task.deliver_now
    end

    send_history
  end
end
