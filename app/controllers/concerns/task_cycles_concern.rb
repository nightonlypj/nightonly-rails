module TaskCyclesConcern
  extend ActiveSupport::Concern

  private

  def set_holidays(start_date, end_date)
    @holidays = Holiday.where(date: start_date..end_date).index_by(&:date)
  end

  def set_exist_task_events
    @exist_task_events = @task_events.map { |task_event| [{ task_id: task_event.task_cycle.task_id, ended_date: task_event.ended_date }, true] }.to_h
  end

  def cycle_months(start_date, end_date)
    return [*start_date.month..end_date.month] if start_date.year == end_date.year
    return [*start_date.month..12, *1..end_date.month].uniq.sort if start_date.year == end_date.year + 1

    [*1..12]
  end

  def cycle_set_next_events(task_cycle, task, start_date, end_date)
    task_start_date = [start_date, task.started_date].max
    task_end_date = [end_date, task.ended_date].compact.min

    case task_cycle.cycle.to_sym
    when :weekly
      weekly_set_next_events(task_cycle, task_start_date, task_end_date)
    when :monthly
      monthly_set_next_events(task_cycle, task_start_date, task_end_date)
    when :yearly
      yearly_set_next_events(task_cycle, task_start_date, task_end_date)
    else
      # :nocov:
      raise "task_cycle.cycle not found.(#{task_cycle.cycle})[id: #{task_cycle.id}]"
      # :nocov:
    end
  end

  def weekly_set_next_events(task_cycle, task_start_date, task_end_date)
    result = false
    date = task_start_date + ((task_cycle.wday_before_type_cast - task_start_date.wday) % 7).days
    while date <= task_end_date # NOTE: 終了日が期間内のもの。開始日のみ期間内のものは含まれない
      result = true if set_next_events(date, task_cycle, task_start_date)
      date += 1.week
    end

    result
  end

  def monthly_set_next_events(task_cycle, task_start_date, task_end_date)
    result = false
    month = task_start_date.beginning_of_month
    while month <= task_end_date # NOTE: 終了日が期間内のもの。開始日のみ期間内のものは含まれない
      result = true if target_set_next_events(month, task_cycle, task_start_date)
      month += 1.month
    end

    result
  end

  def yearly_set_next_events(task_cycle, task_start_date, task_end_date)
    result = false
    month = task_start_date.beginning_of_month
    while month <= task_end_date # NOTE: 終了日が期間内のもの。開始日のみ期間内のものは含まれない
      if month.month == task_cycle.month
        result = true if target_set_next_events(month, task_cycle, task_start_date)
        break if month.year >= task_end_date.year
      end
      month += 1.month
    end

    result
  end

  def target_set_next_events(month, task_cycle, task_start_date)
    case task_cycle.target&.to_sym
    when :day
      day_set_next_events(month, task_cycle, task_start_date)
    when :business_day
      business_day_set_next_events(month, task_cycle, task_start_date)
    when :week
      week_set_next_events(month, task_cycle, task_start_date)
    else
      # :nocov:
      raise "task_cycle.target not found.(#{task_cycle.target})[id: #{task_cycle.id}]"
      # :nocov:
    end
  end

  def day_set_next_events(month, task_cycle, task_start_date)
    date = month + (task_cycle.day - 1).days
    date = (date - 1.month).end_of_month if date.day != task_cycle.day # NOTE: 存在しない日付は丸められる為
    set_next_events(date, task_cycle, task_start_date)
  end

  def business_day_set_next_events(month, task_cycle, task_start_date)
    date = month.end_of_month
    if task_cycle.business_day < date.day # NOTE: 最終営業日は月末（後続処理で休日の場合は前日）
      count = 0
      date = month
      loop do
        count += 1 unless holiday?(date)
        break if count == task_cycle.business_day
        break if date >= month.end_of_month

        date += 1.day
      end
    end
    set_next_events(date, task_cycle, task_start_date)
  end

  def week_set_next_events(month, task_cycle, task_start_date)
    date = month + ((task_cycle.wday_before_type_cast - month.wday) % 7).days + ((task_cycle.week_before_type_cast - 1) * 7).days
    date -= 7.days while date.month > month.month
    set_next_events(date, task_cycle, task_start_date)
  end

  def set_next_events(date, task_cycle, task_start_date)
    event_end_date = handling_holiday_date(date, task_cycle.handling_holiday&.to_sym)
    return if event_end_date < task_start_date
    return unless @months.blank? || @months.include?(event_end_date.strftime('%Y%m'))

    event_start_date = end_to_start_date(event_end_date, task_cycle.period)
    if @exist_task_events.key?(task_id: task_cycle.task_id, ended_date: event_end_date)
      false
    else
      @next_events[{ task_id: task_cycle.task_id, ended_date: event_end_date }] = [task_cycle, event_start_date, event_end_date]
      true
    end
  end

  def handling_holiday_date(date, handling_holiday)
    add_day = handling_holiday == :after ? 1.day : -1.day
    date += add_day while holiday?(date)

    date
  end

  def end_to_start_date(date, period)
    count = 1
    while count < period
      date -= 1.day
      next if holiday?(date)

      count += 1
    end

    date
  end

  def holiday?(date)
    @holidays[date].present? || [0, 6].include?(date.wday) # NOTE: 土日もスキップ
  end
end
