json.extract! task_event, :id, :space_id, :task_cycle_id, :created_at, :updated_at
json.url task_event_url(task_event, format: :json)
