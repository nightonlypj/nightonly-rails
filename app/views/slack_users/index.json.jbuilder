json.success true
json.alert alert if alert.present?
json.notice notice if notice.present?

json.slack_users do
  json.array! @slack_domains.each do |slack_domain|
    json.name slack_domain.name
    json.memberid @slack_users[slack_domain.id]&.memberid
  end
end
