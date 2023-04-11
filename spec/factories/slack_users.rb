FactoryBot.define do
  factory :slack_user do
    slack_domain { nil }
    user { nil }
    memberid { 'MyString' }
    string { 'MyString' }
  end
end
