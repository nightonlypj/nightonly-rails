json.success true
json.notice notice if notice.present?

json.send_setting do
  if @send_setting.blank?
    json.email do
      json.enabled false
    end
    json.slack do
      json.enabled false
    end

    json.start_notice do
      json.start_hour Settings.default_start_notice_start_hour
      json.completed Settings.default_start_notice_completed
      json.required Settings.default_start_notice_required
    end
    json.next_notice do
      json.start_hour Settings.default_next_notice_start_hour
      json.completed Settings.default_next_notice_completed
      json.required Settings.default_next_notice_required
    end
  else
    json.partial! 'send_setting', send_setting: @send_setting
  end
end

if @current_slack_user.present?
  json.current_slack_user do
    json.memberid @current_slack_user.memberid
  end
end
