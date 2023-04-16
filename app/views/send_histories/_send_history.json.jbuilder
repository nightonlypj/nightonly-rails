json.extract! send_history, :id, :space_id, :send_setting_id, :created_at, :updated_at
json.url send_history_url(send_history, format: :json)
