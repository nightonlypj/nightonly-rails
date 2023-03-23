json.next_events do
  json.array! next_events.each do |task_cycle, start_date, end_date|
    json.task_id task_cycle.task_id
    json.start l(start_date, format: :json)
    json.end l(end_date, format: :json) if start_date != end_date
  end
end
