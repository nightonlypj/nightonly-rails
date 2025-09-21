namespace :task_event do
  namespace :create_send_notice do
    desc '期間内のタスクイベント作成＋通知（作成・通知は開始時間以降）'
    task(:now, [:dry_run] => :environment) do |_, args|
      Rake::Task['task_event:create_send_notice'].invoke(Time.zone.today, args.dry_run, 'true')
    end
  end

  desc '期間内のタスクイベント作成＋通知（当日に実行できなかった場合に手動実行）'
  task(:create_send_notice, %i[target_date dry_run send_notice] => :environment) do |task, args|
    include TasksConcern
    include TaskCyclesConcern

    @months = nil

    raise '日付が指定されていません。' if args.target_date.blank?

    begin
      target_date = args.target_date.to_date
    rescue StandardError => e
      raise "日付の形式が不正です。(#{e.message})"
    end
    raise '翌日以降の日付は指定できません。' if target_date >= Time.zone.today + 1.day

    args.with_defaults(dry_run: 'true', send_notice: 'false')
    dry_run = (args.dry_run != 'false')
    send_notice = args.send_notice == 'true'

    @logger = new_logger(task.name)
    @logger.info("=== START #{task.name} ===")
    @logger.info("target_date: #{target_date}, dry_run: #{dry_run}, send_notice: #{send_notice}")

    total_insert_count = 0
    total_notice_count = 0
    ActiveRecord::Base.connection_pool.with_connection do # NOTE: 念の為（PG::UnableToSend: no connection to the server対策）
      start_date = target_date - 31.days # NOTE: 期間が20営業日でも1ヶ月を超える場合がある為
      end_date = target_date + 31.days
      set_holidays(start_date, end_date) # NOTE: 1ヶ月以上の休みはない前提
      before_business_date = handling_holiday_date(target_date, :before)
      after_business_date = handling_holiday_date(target_date, :after)
      prev_business_date = handling_holiday_date(target_date - 1.day, :before)
      next_business_date = handling_holiday_date(target_date + 1.day, :after)
      business_date = "#{before_business_date}, #{after_business_date}, #{prev_business_date}, #{next_business_date}"
      @logger.info("start_date: #{start_date}, end_date: #{end_date}, business_date: #{business_date}")

      spaces = Space.create_send_notice_target
      count = spaces.count
      spaces.each.with_index(1) do |space, index|
        send_setting = space.send_setting_active.first
        next_notice_start_hour = send_setting&.next_notice_start_hour || Settings.default_next_notice_start_hour
        next_notice = before_business_date + next_notice_start_hour.hours <= Time.current
        next_start_date = next_notice ? next_business_date : target_date # NOTE: 翌営業日分は開始時間以降に作成

        next_notice_start = "#{next_notice_start_hour}#{'(default)' if send_setting.blank?}"
        @logger.info("[#{index}/#{count}] space.id: #{space.id}, next_notice_start: #{next_notice_start}, next_start_date: #{next_start_date}")

        # タスクイベント作成
        total_insert_count += create_task_events(dry_run, space, target_date, next_start_date, start_date, end_date)

        # タスクイベント通知
        next if !send_notice || send_setting.blank? || (!send_setting.slack_enabled && !send_setting.email_enabled)
        next if target_date != after_business_date # NOTE: 営業日のみ通知

        if next_notice
          notice_target = :next
          complete_start_date = target_date
        else
          @logger.info("start_notice_start: #{send_setting.start_notice_start_hour}")
          next if target_date + send_setting.start_notice_start_hour.hours > Time.current # NOTE: (開始確認)開始時間以降に通知

          notice_target = :start
          complete_start_date = prev_business_date
        end

        total_notice_count += send_notice_task_events(dry_run, space, target_date, complete_start_date, notice_target, send_setting)
      end
    end

    @logger.info("Total insert: #{total_insert_count}, notice: #{total_notice_count}")
    @logger.info("=== END #{task.name} ===")
  end

  # タスクイベント作成
  def create_task_events(dry_run, space, target_date, next_start_date, start_date, end_date)
    task_cycles = TaskCycle.active.where(space:).by_month(cycle_months(start_date, end_date) + [nil])
      .eager_load(task: :task_assigne).by_task_period(target_date, end_date).merge(Task.order(:priority)).order(:order, :updated_at, :id)
    @logger.info("task_cycles.count: #{task_cycles.count}")
    return 0 if task_cycles.none?

    @task_events = TaskEvent.where(space:, started_date: start_date..)
      .eager_load(task_cycle: :task).merge(Task.order(:priority)).order(:id)
    set_exist_task_events
    @logger.debug("@exist_task_events: #{@exist_task_events}")

    @next_events = {}
    task_cycles.each do |task_cycle|
      cycle_set_next_events(task_cycle, task_cycle.task, start_date, end_date)
    end
    insert_events = @next_events.values.filter { |_, event_start_date, event_end_date| event_start_date <= next_start_date && event_end_date >= target_date }
    @logger.info("insert: #{insert_events.count}")
    return 0 if insert_events.none?

    codes = create_unique_codes(insert_events.count)
    now = Time.current
    insert_params = { space_id: space.id, created_at: now, updated_at: now }
    ActiveRecord::Base.transaction do
      insert_datas = insert_events.map.with_index do |(task_cycle, event_start_date, event_end_date), insert_index|
        user_id = nil
        user_ids = task_cycle.task.task_assigne&.user_ids&.split(',')
        if user_ids.present?
          users = task_assigne_users(user_ids, space)
          index = user_ids.index { |id| users[id.to_i].present? }
          if index.present?
            user_id = user_ids[index]

            task_cycle.task.task_assigne.user_ids = (user_ids[(index + 1)..] + user_ids[0..index]).join(',')
            task_cycle.task.task_assigne.save!
          end
        end

        insert_params.merge(code: codes[insert_index], task_cycle_id: task_cycle.id,
                            started_date: event_start_date, ended_date: event_end_date, last_ended_date: event_end_date,
                            init_assigned_user_id: user_id, assigned_user_id: user_id, assigned_at: user_id.present? ? now : nil)
      end
      @logger.debug("insert_datas: #{insert_datas}")
      TaskEvent.insert_all!(insert_datas) if !dry_run && insert_datas.present?
    end

    insert_events.count
  end

  # ユニークコード作成
  def create_unique_codes(count)
    unique_codes = []
    try_count = 1
    loop do
      codes = Array.new(count - unique_codes.count) { Digest::MD5.hexdigest(SecureRandom.uuid).to_i(16).to_s(36).rjust(25, '0') }
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
  def send_notice_task_events(dry_run, space, target_date, complete_start_date, notice_target, send_setting)
    enable_send_target = get_enable_send_target(space, target_date, notice_target, send_setting)
    return 0 unless enable_send_target.values.any?

    # REVIEW: dry_runでは今回作成分が対象にならない
    @processing_task_events = TaskEvent.where(space:).where.not(status: TaskEvent::NOT_NOTICE_STATUS)
      .eager_load(task_cycle: :task).order(:status).merge(Task.order(:priority)).order(:id)
    set_task_event_datas(notice_target, target_date)

    if send_setting["#{notice_target}_notice_completed"]
      @completed_task_events = TaskEvent.where(space:, status: TaskEvent::NOT_NOTICE_STATUS,
                                               last_completed_at: complete_start_date.beginning_of_day..target_date.end_of_day)
        .eager_load(task_cycle: :task).order(:last_completed_at)
    else
      @completed_task_events = []
    end

    notice_count = 0
    history_params = send_history_params(space, send_setting, notice_target, target_date)
    SendHistory.send_targets.each_key do |send_target|
      next unless enable_send_target[send_target]

      send_history = SendHistory.new(history_params.merge(send_target:, started_at: Time.current))
      if !send_setting["#{notice_target}_notice_required"] && @processing_task_events.none? && @completed_task_events.none?
        send_history.status = :skip
        send_history.completed_at = Time.current
        send_history.save! unless dry_run
        next
      end

      notice_count += 1
      next if dry_run

      case send_target.to_sym
      when :slack
        send_history.save!
        NoticeSlack::IncompleteTaskJob.perform_later(send_history.id)
      when :email
        # NOTE: send_history.save!はNoticeMailerで実施
        NoticeMailer.with(
          target_date:,
          send_history:,
          next_task_events: @next_task_events.values,
          expired_task_events: @expired_task_events.values,
          end_today_task_events: @end_today_task_events.values,
          date_include_task_events: @date_include_task_events.values,
          completed_task_events: @completed_task_events
        ).incomplete_task.deliver_now
      else
        # :nocov:
        raise "send_target not found.(#{send_target})"
        # :nocov:
      end
    end

    @logger.info("notice_count: #{notice_count}")
    notice_count
  end

  # 送信対象毎の通知有無 # NOTE: 最終ステータスが失敗の場合は再通知
  def get_enable_send_target(space, target_date, notice_target, send_setting)
    last_statuss = {}
    send_histories = SendHistory.where(space:, target_date:, notice_target:).order(id: :desc)
    send_histories.each do |send_history|
      last_statuss[send_history.send_target] = send_history.status unless last_statuss.key?(send_history.send_target)
      break if SendHistory.send_targets.keys - last_statuss.keys == []
    end
    @logger.debug("last_statuss: #{last_statuss}")

    enable_send_target = {}
    SendHistory.send_targets.each_key do |send_target|
      enabled = send_setting["#{send_target}_enabled"]
      enabled = false if enabled && last_statuss[send_target].present? && last_statuss[send_target].to_sym != :failure

      enable_send_target[send_target] = enabled
    end
    @logger.debug("enable_send_target: #{enable_send_target}")

    enable_send_target
  end

  def set_task_event_datas(notice_target, target_date)
    @next_task_events = {}
    @expired_task_events = {}
    @end_today_task_events = {}
    @date_include_task_events = {}
    @processing_task_events.each do |task_event|
      if task_event.started_date > target_date
        @next_task_events[task_event.id] = task_event if notice_target == :next
      elsif task_event.last_ended_date < target_date
        @expired_task_events[task_event.id] = task_event
      elsif task_event.last_ended_date == target_date
        @end_today_task_events[task_event.id] = task_event
      else
        @date_include_task_events[task_event.id] = task_event
      end
    end
  end

  def send_history_params(space, send_setting, notice_target, target_date)
    {
      space:,
      send_setting:,
      target_date:,
      notice_target:,
      target_count: @processing_task_events.count + @completed_task_events.count,
      next_task_event_ids: @next_task_events.present? ? @next_task_events.keys.join(',') : nil,
      expired_task_event_ids: @expired_task_events.present? ? @expired_task_events.keys.join(',') : nil,
      end_today_task_event_ids: @end_today_task_events.present? ? @end_today_task_events.keys.join(',') : nil,
      date_include_task_event_ids: @date_include_task_events.present? ? @date_include_task_events.keys.join(',') : nil,
      completed_task_event_ids: @completed_task_events.present? ? @completed_task_events.ids.join(',') : nil
    }
  end
end
