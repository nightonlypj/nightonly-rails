json.extract! task_send_history, :id, :space_id, :task_send_setting_id, :created_at, :updated_at
json.url task_send_history_url(task_send_history, format: :json)
