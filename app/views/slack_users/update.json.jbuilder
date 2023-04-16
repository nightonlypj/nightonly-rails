json.success true
json.alert alert if alert.present?
json.notice notice if notice.present?

json.slack_users do
  json.array! @slack_users.each do |slack_user|
    json.name slack_user.slack_domain.name
    json.memberid slack_user.memberid
  end
end
