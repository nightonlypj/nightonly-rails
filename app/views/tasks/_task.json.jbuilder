json.id task.id
json.priority task.priority
json.priority_i18n task.priority_i18n
json.title task.title
json.started_date l(task.started_date, format: :json)
json.ended_date l(task.ended_date, format: :json, default: nil)
