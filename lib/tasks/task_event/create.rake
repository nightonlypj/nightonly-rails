namespace :task_event do
  namespace :create do
    desc '翌営業日のタスクイベント作成' # 夕方の通知前に実行
    task(:next, [:dry_run] => :environment) do |_, args|
      Rake::Task['task_event:create'].invoke(Time.current.to_date.tomorrow, args.dry_run, :next)
    end

    desc '本日（休日の場合は翌営業日）のタスクイベント作成' # 朝の通知前に実行（前営業日夕方以降に追加・変更されたタスク向け）
    task(:today, [:dry_run] => :environment) do |_, args|
      Rake::Task['task_event:create'].invoke(Time.current.to_date, args.dry_run, :today)
    end
  end

  desc '指定日（休日の場合は翌営業日）のタスクイベント作成'
  task(:create, %i[start_date dry_run target] => :environment) do |task, args|
    include TaskCyclesConcern

    begin
      start_date = args.start_date&.to_date
      raise '日付が指定されていません。' if start_date.blank?
      raise '翌々日以降の日付は指定できません。' if start_date > Time.current.to_date.tomorrow
    rescue StandardError
      raise '日付の形式が不正です。'
    end
    args.with_defaults(dry_run: 'true')
    dry_run = (args.dry_run != 'false')

    logger = new_logger(task.name)
    logger.info("=== START #{task.name} ===")
    logger.info("#{args.target || 'blank'}, start_date: #{start_date}, dry_run: #{dry_run}")

    total_insert_count = 0
    ActiveRecord::Base.connection_pool.with_connection do # NOTE: 念の為（PG::UnableToSend: no connection to the server対策）
      end_date = start_date + 31.days # NOTE: 期間が20営業日でも1ヶ月を超える場合がある為
      set_holidays(start_date, end_date)

      business_date = handling_holiday_date(start_date, :after)
      logger.info("business_date: #{business_date}")

      spaces = Space.order(:id)
      count = spaces.count
      now = Time.current
      @months = nil
      spaces.each.with_index(1) do |space, index|
        task_cycles = TaskCycle.active.where(space: space).by_month(cycle_months(business_date, end_date) + [nil])
                               .eager_load(:task).by_task_period(business_date, end_date).merge(Task.order(:priority, :id))
        logger.info("[#{index}/#{count}] space.id: #{space.id}, task_cycles.count: #{task_cycles.count}")
        next if task_cycles.count.zero?

        task_events = TaskEvent.where(space: space, started_date: start_date..business_date)
                               .eager_load(task_cycle: :task).merge(Task.order(:priority, :id)).order(:id)
        @task_event_exists = task_events.map { |task_event| [{ task_cycle_id: task_event.task_cycle_id, ended_date: task_event.ended_date }, true] }.to_h
        logger.debug("@task_event_exists: #{@task_event_exists}")

        @next_events = []
        task_cycles.each do |task_cycle|
          cycle_set_next_events(task_cycle, task_cycle.task, business_date, end_date)
        end
        insert_events = @next_events.filter { |_, event_start_date, _| event_start_date == business_date }
        total_insert_count += insert_events.count
        logger.info("insert: #{insert_events.count}")
        next if insert_events.count.zero?

        insert_datas = insert_events.map do |task_cycle, event_start_date, event_end_date|
          { space_id: space.id, task_cycle_id: task_cycle.id, started_date: event_start_date, ended_date: event_end_date, created_at: now, updated_at: now }
        end
        logger.debug("insert_datas: #{insert_datas}")
        next if dry_run

        TaskEvent.insert_all!(insert_datas) if insert_datas.present?
      end
    end

    logger.info("Total insert: #{total_insert_count}")
    logger.info("=== END #{task.name} ===")
  end
end
