FactoryBot.define do
  factory :task_send_setting do
    today_notice_start_hour  { 10 }
    # today_notice_required    { false }
    next_notice_start_hour { 17 }
    # next_notice_required   { false }
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
