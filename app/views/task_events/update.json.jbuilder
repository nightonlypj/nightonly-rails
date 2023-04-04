json.success true
json.alert alert if alert.present?
json.notice notice if notice.present?

json.event do
  json.partial! 'task_event', task_event: @task_event, detail: @detail
end
