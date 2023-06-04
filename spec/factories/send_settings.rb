FactoryBot.define do
  factory :send_setting do
    slack_enabled           { false }
    email_enabled           { false }
    start_notice_start_hour { Settings.default_start_notice_start_hour }
    start_notice_completed  { Settings.default_start_notice_completed }
    start_notice_required   { Settings.default_start_notice_required }
    next_notice_start_hour  { Settings.default_next_notice_start_hour }
    next_notice_completed   { Settings.default_next_notice_completed }
    next_notice_required    { Settings.default_next_notice_required }
    # deleted_at              { nil }
    association :space

    trait :changed do
      start_notice_start_hour { Settings.default_start_notice_start_hour - 1 }
      start_notice_completed  { !Settings.default_start_notice_completed }
      start_notice_required   { !Settings.default_start_notice_required }
      next_notice_start_hour  { Settings.default_next_notice_start_hour + 1 }
      next_notice_completed   { !Settings.default_next_notice_completed }
      next_notice_required    { !Settings.default_next_notice_required }
    end

    # Slack
    trait :slack do
      slack_enabled      { true }
      slack_webhook_url  { Faker::Internet.url(scheme: 'https') }
      slack_mention      { '!here' }
      association :slack_domain
    end

    # メール
    trait :email do
      email_enabled { true }
      email_address { Faker::Internet.email }
    end

    # 論理削除
    trait :deleted do
      deleted_at { Time.current - 1.day }
    end

    trait :before_updated do
      updated_at { Time.current - 1.day }
    end
  end
end
