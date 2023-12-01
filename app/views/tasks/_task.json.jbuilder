json.id task.id
json.priority task.priority
json.priority_i18n task.priority_i18n
json.title task.title
if detail
  json.summary task.summary
  json.premise task.premise
  json.process task.process
end
json.started_date l(task.started_date, format: :json)
json.ended_date l(task.ended_date, format: :json, default: nil)

if task.created_user_id.present?
  json.created_user do
    json.partial! '/users/auth/user', user: task.created_user, use_email: current_member&.power_admin? if task.created_user.present?
    json.deleted task.created_user.blank?
  end
end
json.created_at l(task.created_at, format: :json)

if task.last_updated_user_id.present?
  json.last_updated_user do
    json.partial! '/users/auth/user', user: task.last_updated_user, use_email: current_member&.power_admin? if task.last_updated_user.present?
    json.deleted task.last_updated_user.blank?
  end
end
json.last_updated_at l(task.last_updated_at, format: :json, default: nil)
