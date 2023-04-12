json.success true
json.alert alert if alert.present?
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
      json.required Settings.default_start_notice_required
    end
    json.next_notice do
      json.start_hour Settings.default_next_notice_start_hour
      json.required Settings.default_next_notice_required
    end
  else
    json.partial! 'send_setting', send_setting: @send_setting
  end
end
