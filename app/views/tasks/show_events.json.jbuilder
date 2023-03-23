json.success true
json.alert alert if alert.present?
json.notice notice if notice.present?

# TODO: 通知用を作ったらそっちも

json.partial! 'next_events', next_events: @next_events

json.task do
  json.partial! 'task', task: @task
end
