json.array! task_events.each do |task_event|
  json.partial! 'task_event', task: task, task_event: task_event, detail: false
end
json.array! next_events.each do |task_cycle, start_date, end_date|
  json.cycle_id task_cycle.id
  json.task_id task_cycle.task_id
  json.priority_order Settings.priority_order[task.present? ? task.priority : task_cycle.task.priority]
  json.started_date l(start_date, format: :json)
  json.last_ended_date l(end_date, format: :json)
end
