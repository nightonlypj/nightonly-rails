FactoryBot.define do
  factory :task do
    priority         { :high }
    sequence(:title) { |n| "task(#{n})" }
    summary          { "#{title}の概要" }
    premise          { "#{title}の前提" }
    process          { "#{title}の手順" }
    started_date     { Time.zone.today }
    ended_date       { started_date + 1.year }
    association :space
    association :created_user, factory: :user

    # 優先度
    trait :high do
      # priority { :high }
    end
    trait :middle do
      priority { :middle }
    end
    trait :low do
      priority { :low }
    end
    trait :none do
      priority { :none }
    end

    # 開始前
    trait :before do
      started_date { Time.zone.today + 1.day }
      ended_date   { started_date }
    end
    # 期間内
    trait :active do
      # started_date { Time.zone.today }
      ended_date   { started_date }
    end
    # 終了後
    trait :after do
      started_date { Time.zone.today - 1.day }
      ended_date   { started_date }
      to_create { |instance| instance.save(validate: false) }
    end

    trait :no_end do
      ended_date { nil }
    end
  end
end
