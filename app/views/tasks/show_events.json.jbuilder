json.success true
json.notice notice if notice.present?

json.events do
  json.partial! '/task_events/events', task_events: @task_events, next_events: @next_events.values, task: @task, current_member: @current_member
end

json.task do
  json.partial! 'task', task: @task, detail: @detail, current_member: @current_member
end
