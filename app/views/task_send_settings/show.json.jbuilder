json.success true
json.alert alert if alert.present?
json.notice notice if notice.present?

json.task_send_setting do
  if @task_send_setting.blank?
    json.email do
      json.enabled false
    end
    json.slack do
      json.enabled false
    end

    json.today_notice do
      json.start_hour Settings.default_today_notice_start_hour
      json.required Settings.default_today_notice_required
    end
    json.next_notice do
      json.start_hour Settings.default_next_notice_start_hour
      json.required Settings.default_next_notice_required
    end
  else
    json.partial! 'task_send_setting', task_send_setting: @task_send_setting
  end
end
