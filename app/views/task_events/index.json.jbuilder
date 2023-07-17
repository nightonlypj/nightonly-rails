json.success true
json.search_params do
  json.start_date l(@start_date, format: :json)
  json.end_date l(@end_date, format: :json)
end

json.events do
  json.partial! 'events', task_events: @task_events, next_events: @next_events.values, task: nil, current_member: @current_member
end

json.tasks do
  json.array! @tasks.each_value do |task|
    json.partial! './tasks/task', task:, detail: false, current_member: @current_member
  end
end
