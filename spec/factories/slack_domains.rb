FactoryBot.define do
  factory :slack_domain do
    name { Faker::Internet.domain_name }
  end
end
