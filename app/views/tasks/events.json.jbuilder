json.success true
json.search_params do
  json.start_date l(@start_date, format: :json)
  json.end_date l(@end_date, format: :json)
end

# TODO: 通知用を作ったらそっちも

json.next_events do
  json.array! @next_events.each do |task_cycle, start_date, end_date|
    json.start l(start_date, format: :json)
    json.end l(end_date, format: :json) if start_date != end_date

    json.task_id task_cycle.task_id
    json.task_cycles do
      json.partial! 'task_cycle', task_cycle: task_cycle
    end
  end
end

json.tasks do
  json.array! @tasks.each_value do |task|
    json.partial! 'task', task: task
  end
end
