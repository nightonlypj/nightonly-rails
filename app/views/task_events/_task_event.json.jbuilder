json.code task_event.code
json.cycle_id task_event.task_cycle_id
json.task_id task_event.task_cycle.task_id
json.priority_order Settings.priority_order[task.present? ? task.priority : task_event.task_cycle.task.priority]
json.started_date l(task_event.started_date, format: :json)
json.last_ended_date l(task_event.last_ended_date, format: :json)
json.status task_event.status
json.status_i18n task_event.status_i18n
return unless detail

json.last_completed_at l(task_event.last_completed_at, format: :json, default: nil)

if task_event.assigned_user_id.present?
  json.assigned_user do
    json.partial! './users/auth/user', user: task_event.assigned_user, use_email: true if task_event.assigned_user.present?
    json.deleted task_event.assigned_user.blank?
  end
end
json.assigned_at l(task_event.assigned_at, format: :json, default: nil)

json.memo task_event.memo

if task_event.last_updated_user_id.present?
  json.last_updated_user do
    json.partial! './users/auth/user', user: task_event.last_updated_user, use_email: true if task_event.last_updated_user.present?
    json.deleted task_event.last_updated_user.blank?
  end
end
json.last_updated_at l(task_event.last_updated_at, format: :json, default: nil)
