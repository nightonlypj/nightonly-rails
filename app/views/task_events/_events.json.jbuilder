json.array! task_events.each do |task_event|
  json.code task_event.code
  json.cycle_id task_event.task_cycle_id
  json.task_id task_event.task_cycle.task_id
  json.priority_order Settings.priority_order[task.present? ? task.priority : task_event.task_cycle.task.priority]
  json.start l(task_event.started_date, format: :json)
  json.end l(task_event.ended_date, format: :json) if task_event.started_date != task_event.ended_date
  json.status task_event.status
  json.status_i18n task_event.status_i18n
end
json.array! next_events.each do |task_cycle, start_date, end_date|
  json.cycle_id task_cycle.id
  json.task_id task_cycle.task_id
  json.priority_order Settings.priority_order[task.present? ? task.priority : task_cycle.task.priority]
  json.start l(start_date, format: :json)
  json.end l(end_date, format: :json) if start_date != end_date
end
