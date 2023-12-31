return if task_assigne_user_ids.blank?

json.assigne_users do
  json.array! task_assigne_user_ids do |task_assigne_user_id|
    user_id = task_assigne_user_id.to_i
    next if task_assigne_users[user_id].blank?

    json.partial! '/users/auth/user', user: task_assigne_users[user_id], use_email: @current_member&.power_admin?
  end
end
