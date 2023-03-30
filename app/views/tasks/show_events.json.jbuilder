json.success true
json.alert alert if alert.present?
json.notice notice if notice.present?

json.events do
  json.partial! './task_events/events', task_events: @task_events, next_events: @next_events
end

json.task do
  json.partial! 'task', task: @task, use_add_info: false
end
