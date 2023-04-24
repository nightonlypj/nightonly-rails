json.success true
json.alert alert if alert.present?
json.notice notice if notice.present?

json.count @ids.count
json.destroy_count @destroy_count
