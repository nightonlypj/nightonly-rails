namespace :task_event do
  namespace :create do
    desc '今日が期間内のタスクイベント作成（朝の通知前に自動実行）' # 前営業日夕方以降に追加・変更されたタスクが対象
    task(:today, [:dry_run] => :environment) do |_, args|
      Rake::Task['task_event:create'].invoke(Time.current.to_date, args.dry_run, :today)
    end

    desc '翌営業日が期間内のタスクイベント作成（夕方の通知前に自動実行）'
    task(:next, [:dry_run] => :environment) do |_, args|
      Rake::Task['task_event:create'].invoke(Time.current.to_date.tomorrow, args.dry_run, :next)
    end
  end

  desc '対象日が期間内のタスクイベント作成（当日に実行できなかった場合に手動実行）'
  task(:create, %i[target_date dry_run target] => :environment) do |task, args|
    include TaskCyclesConcern

    begin
      target_date = args.target_date&.to_date
      raise '日付が指定されていません。' if target_date.blank?
      raise '翌々日以降の日付は指定できません。' if target_date > Time.current.to_date.tomorrow
    rescue StandardError
      raise '日付の形式が不正です。'
    end
    args.with_defaults(dry_run: 'true')
    dry_run = (args.dry_run != 'false')
    target = args.target || 'blank'

    logger = new_logger(task.name)
    logger.info("=== START #{task.name} ===")
    logger.info("#{target}, target_date: #{target_date}, dry_run: #{dry_run}")

    total_insert_count = 0
    ActiveRecord::Base.connection_pool.with_connection do # NOTE: 念の為（PG::UnableToSend: no connection to the server対策）
      tomorrow = Time.current.to_date.tomorrow
      set_holidays(tomorrow, tomorrow + 1.month) # NOTE: 1ヶ月以上の休みはない前提
      next_business_date = handling_holiday_date(tomorrow, :after)
      next_start_date = target == :next ? next_business_date : target_date
      logger.info("next_business_date: #{next_business_date}, next_start_date: #{next_start_date}")

      start_date = target_date - 31.days # NOTE: 期間が20営業日でも1ヶ月を超える場合がある為
      end_date = target_date + 31.days
      set_holidays(start_date, end_date)

      spaces = Space.order(:id)
      count = spaces.count
      now = Time.current
      @months = nil
      spaces.each.with_index(1) do |space, index|
        task_cycles = TaskCycle.active.where(space: space).by_month(cycle_months(start_date, end_date) + [nil])
                               .eager_load(:task).by_task_period(next_start_date, next_start_date).merge(Task.order(:priority, :id))
        logger.info("[#{index}/#{count}] space.id: #{space.id}, task_cycles.count: #{task_cycles.count}")
        next if task_cycles.count.zero?

        task_events = TaskEvent.where(space: space, started_date: start_date.., ended_date: ..next_business_date)
                               .eager_load(task_cycle: :task).merge(Task.order(:priority, :id)).order(:id)
        @exist_task_events = task_events.map { |task_event| [{ task_cycle_id: task_event.task_cycle_id, ended_date: task_event.ended_date }, true] }.to_h
        logger.debug("@exist_task_events: #{@exist_task_events}")

        @next_events = []
        task_cycles.each do |task_cycle|
          cycle_set_next_events(task_cycle, task_cycle.task, start_date, end_date)
        end
        insert_events = @next_events.filter { |_, event_start_date, event_end_date| event_start_date <= next_start_date && event_end_date >= next_start_date }
        total_insert_count += insert_events.count
        logger.info("insert: #{insert_events.count}")
        next if insert_events.count.zero?

        index = -1
        codes = create_unique_codes(insert_events.count)
        insert_datas = insert_events.map do |task_cycle, event_start_date, event_end_date|
          index += 1
          { code: codes[index], space_id: space.id, task_cycle_id: task_cycle.id, started_date: event_start_date, ended_date: event_end_date, created_at: now, updated_at: now }
        end
        logger.debug("insert_datas: #{insert_datas}")
        next if dry_run

        TaskEvent.insert_all!(insert_datas) if insert_datas.present?
      end
    end

    logger.info("Total insert: #{total_insert_count}")
    logger.info("=== END #{task.name} ===")
  end

  def create_unique_codes(count)
    unique_codes = []
    try_count = 1
    loop do
      codes = (count - unique_codes.count).times.map { Digest::MD5.hexdigest(SecureRandom.uuid).to_i(16).to_s(36).rjust(25, '0') }
      unique_codes += codes - TaskEvent.where(code: codes).pluck(:code)
      return unique_codes if unique_codes.count >= count

      # :nocov:
      if try_count < 10
        logger.warn("[WARN](#{try_count})Not unique code(#{codes})")
      elsif try_count >= 10
        message = "[ERROR](#{try_count})Not unique code(#{codes})"
        logger.error(message)
        raise message
      end
      try_count += 1
      # :nocov:
    end
  end
end
