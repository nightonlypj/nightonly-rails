json.slack do
  json.enabled task_send_setting.slack_enabled
  if @current_member.present?
    json.webhook_url task_send_setting.slack_webhook_url
    json.mention task_send_setting.slack_mention
  end
end
json.email do
  json.enabled task_send_setting.email_enabled
  json.address task_send_setting.email_address if @current_member.present?
end

json.today_notice do
  json.start_hour task_send_setting.today_notice_start_hour
  json.required task_send_setting.today_notice_required
end
json.next_notice do
  json.start_hour task_send_setting.next_notice_start_hour
  json.required task_send_setting.next_notice_required
end

if task_send_setting.last_updated_user_id.present?
  json.last_updated_user do
    json.partial! './users/auth/user', user: task_send_setting.last_updated_user, use_email: true if task_send_setting.last_updated_user.present?
    json.deleted task_send_setting.last_updated_user.blank?
  end
end
json.last_updated_at l(task_send_setting.updated_at, format: :json, default: nil)
