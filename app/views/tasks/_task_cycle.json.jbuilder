json.cycle task_cycle.cycle
json.cycle_i18n task_cycle.cycle_i18n
json.month task_cycle.month if task_cycle.cycle_yearly?

if task_cycle.cycle_monthly_or_yearly?
  json.target task_cycle.target
  json.target_i18n task_cycle.target_i18n
  case task_cycle.target&.to_sym
  when :day
    json.day task_cycle.day
  when :business_day
    json.business_day task_cycle.business_day
  when :week
    json.week task_cycle.week
    json.week_i18n task_cycle.week_i18n
  end
end

if task_cycle.cycle_weekly? || (task_cycle.cycle_monthly_or_yearly? && task_cycle.target_week?)
  json.wday task_cycle.wday
  json.wday_i18n task_cycle.wday_i18n
end
if task_cycle.cycle_weekly? || (task_cycle.cycle_monthly_or_yearly? && task_cycle.target_day_or_week?)
  json.handling_holiday task_cycle.handling_holiday
  json.handling_holiday_i18n task_cycle.handling_holiday_i18n
end

json.period task_cycle.period
