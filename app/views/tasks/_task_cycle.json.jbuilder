json.cycle task_cycle.cycle
json.cycle_i18n task_cycle.cycle_i18n
json.month task_cycle.month if task_cycle.month.present?

json.day task_cycle.day if task_cycle.day.present?
json.business_day task_cycle.business_day if task_cycle.business_day.present?
if task_cycle.week.present?
  json.week task_cycle.week
  json.week_i18n task_cycle.week_i18n
end

if task_cycle.wday.present?
  json.wday task_cycle.wday
  json.wday_i18n task_cycle.wday_i18n
end
if task_cycle.handling_holiday.present?
  json.handling_holiday task_cycle.handling_holiday
  json.handling_holiday_i18n task_cycle.handling_holiday_i18n
end

json.period task_cycle.period
