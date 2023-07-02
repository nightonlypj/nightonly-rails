FactoryBot.define do
  factory :slack_user do
    memberid { Faker::Number.hexadecimal(digits: Settings.slack_user_memberid_minimum).upcase }
    association :slack_domain
    association :user
  end
end
