json.success true
json.notice notice if notice.present?

json.send_setting do
  json.partial! 'send_setting', send_setting: @send_setting, current_member: @current_member
end

if @current_slack_user.present?
  json.current_slack_user do
    json.memberid @current_slack_user.memberid
  end
end
