FactoryBot.define do
  factory :task_send_setting do
    before_notice_start_hour { 17 }
    today_notice_start_hour  { 10 }
    # before_notice_required   { false }
    # today_notice_required    { false }
    association :space
    association :created_user, factory: :user

    # Email
    trait :email do
      email { Faker::Internet.safe_email }
    end

    # Slack
    trait :slack do
      slack_webhook_url  { Faker::Internet.url }
      slack_team_mention { '@here' }
    end
  end
end
