json.extract! slack_user, :id, :slack_domain_id, :user_id, :memberid, :string, :created_at, :updated_at
json.url slack_user_url(slack_user, format: :json)
