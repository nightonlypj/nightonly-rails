FactoryBot.define do
  factory :task do
    priority         { :high }
    sequence(:title) { |n| "task(#{n})" }
    summary          { "#{title}の概要" }
    premise          { "#{title}の前提" }
    process          { "#{title}の手順" }
    started_date     { Time.current.to_date }
    ended_date       { (Time.current + 1.year).to_date }
    association :space
    association :created_user, factory: :user
  end
end
