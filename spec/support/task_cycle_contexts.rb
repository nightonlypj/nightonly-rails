# テスト内容（共通）
def expect_task_cycle_json(response_json_task_cycle, task_cycle)
  result = 4
  expect(response_json_task_cycle['id']).to eq(task_cycle.id)
  expect(response_json_task_cycle['cycle']).to eq(task_cycle.cycle)
  expect(response_json_task_cycle['cycle_i18n']).to eq(task_cycle.cycle_i18n)
  if task_cycle.cycle_yearly?
    expect(response_json_task_cycle['month']).to eq(task_cycle.month)
    result += 1
  else
    expect(response_json_task_cycle['month']).to be_nil
  end

  if task_cycle.cycle_monthly_or_yearly?
    expect(response_json_task_cycle['target']).to eq(task_cycle.target)
    expect(response_json_task_cycle['target_i18n']).to eq(task_cycle.target_i18n)
    case task_cycle.target&.to_sym
    when :day
      expect(response_json_task_cycle['day']).to eq(task_cycle.day)
      expect(response_json_task_cycle['business_day']).to be_nil
      expect(response_json_task_cycle['week']).to be_nil
      expect(response_json_task_cycle['week_i18n']).to be_nil
      result += 3
    when :business_day
      expect(response_json_task_cycle['day']).to be_nil
      expect(response_json_task_cycle['business_day']).to eq(task_cycle.business_day)
      expect(response_json_task_cycle['week']).to be_nil
      expect(response_json_task_cycle['week_i18n']).to be_nil
      result += 3
    when :week
      expect(response_json_task_cycle['day']).to be_nil
      expect(response_json_task_cycle['business_day']).to be_nil
      expect(response_json_task_cycle['week']).to eq(task_cycle.week)
      expect(response_json_task_cycle['week_i18n']).to eq(task_cycle.week_i18n)
      result += 4
    else
      # :nocov:
      raise "task_cycle.target not found.(#{task_cycle.target})"
      # :nocov:
    end
  else
    expect(response_json_task_cycle['target']).to be_nil
    expect(response_json_task_cycle['target_i18n']).to be_nil
  end

  if task_cycle.cycle_weekly? || (task_cycle.cycle_monthly_or_yearly? && task_cycle.target_week?)
    expect(response_json_task_cycle['wday']).to eq(task_cycle.wday)
    expect(response_json_task_cycle['wday_i18n']).to eq(task_cycle.wday_i18n)
    result += 2
  else
    expect(response_json_task_cycle['wday']).to be_nil
    expect(response_json_task_cycle['wday_i18n']).to be_nil
  end
  if task_cycle.cycle_weekly? || (task_cycle.cycle_monthly_or_yearly? && task_cycle.target_day_or_week?)
    expect(response_json_task_cycle['handling_holiday']).to eq(task_cycle.handling_holiday)
    expect(response_json_task_cycle['handling_holiday_i18n']).to eq(task_cycle.handling_holiday_i18n)
    result += 2
  else
    expect(response_json_task_cycle['handling_holiday']).to be_nil
    expect(response_json_task_cycle['handling_holiday_i18n']).to be_nil
  end

  expect(response_json_task_cycle['period']).to eq(task_cycle.period)

  result
end
