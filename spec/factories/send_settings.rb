FactoryBot.define do
  factory :send_setting do
    start_notice_start_hour { Settings.default_start_notice_start_hour }
    start_notice_completed  { Settings.default_start_notice_completed }
    start_notice_required   { Settings.default_start_notice_required }
    next_notice_start_hour  { Settings.default_next_notice_start_hour }
    next_notice_completed   { Settings.default_next_notice_completed }
    next_notice_required    { Settings.default_next_notice_required }
    association :space

    # Slack
    trait :slack do
      slack_enabled      { true }
      slack_webhook_url  { Faker::Internet.url }
      slack_mention      { '!here' }
    end

    # メール
    trait :email do
      email_enabled { true }
      email_address { Faker::Internet.safe_email }
    end
  end
end
