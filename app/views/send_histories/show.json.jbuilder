json.success true
json.send_history do
  json.partial! 'send_history', send_history: @send_history, detail: true, task_events: @task_events, current_member: @current_member
end
