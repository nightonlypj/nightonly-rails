json.success true
json.send_history do
  json.total_count @send_histories.total_count
  json.current_page @send_histories.current_page
  json.total_pages @send_histories.total_pages
  json.limit_value @send_histories.limit_value
end
json.send_histories do
  json.array! @send_histories do |send_history|
    json.partial! 'send_history', send_history:, detail: false, task_events: @task_events, current_member: @current_member
  end
end
