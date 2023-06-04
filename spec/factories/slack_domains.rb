FactoryBot.define do
  factory :slack_domain do
    sequence(:name) { |n| "example#{n}" }
  end
end
