json.slack do
  json.enabled send_setting.blank? ? false : send_setting.slack_enabled
  if send_setting.present? && current_member.present?
    json.name send_setting.slack_domain&.name
    json.webhook_url send_setting.slack_webhook_url
    json.mention send_setting.slack_mention
  end
end
json.email do
  json.enabled send_setting.blank? ? false : send_setting.email_enabled
  json.address send_setting.email_address if send_setting.present? && current_member.present?
end

json.start_notice do
  json.start_hour send_setting.blank? ? Settings.default_start_notice_start_hour : send_setting.start_notice_start_hour
  json.completed send_setting.blank? ? Settings.default_start_notice_completed : send_setting.start_notice_completed
  json.required send_setting.blank? ? Settings.default_start_notice_required : send_setting.start_notice_required
end
json.next_notice do
  json.start_hour send_setting.blank? ? Settings.default_next_notice_start_hour : send_setting.next_notice_start_hour
  json.completed send_setting.blank? ? Settings.default_next_notice_completed : send_setting.next_notice_completed
  json.required send_setting.blank? ? Settings.default_next_notice_required : send_setting.next_notice_required
end

if send_setting&.last_updated_user_id.present?
  json.last_updated_user do
    json.partial! './users/auth/user', user: send_setting.last_updated_user, use_email: current_member&.power_admin? if send_setting.last_updated_user.present?
    json.deleted send_setting.last_updated_user.blank?
  end
end
json.last_updated_at l(send_setting.updated_at, format: :json) if send_setting.present?
