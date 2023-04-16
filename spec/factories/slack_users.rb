FactoryBot.define do
  factory :slack_user do
    memberid { Faker::Number.hexadecimal(digits: 11).upcase }
    association :slack_domain
    association :user
  end
end
