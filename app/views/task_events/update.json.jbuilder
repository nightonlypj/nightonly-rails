json.success true
json.notice notice if notice.present?

json.event do
  json.partial! 'task_event', task: nil, task_event: @task_event, detail: @detail, current_member: @current_member
end
