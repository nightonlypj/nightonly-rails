FactoryBot.define do
  factory :task_event do
    code            { Utils::UniqueCodeGenerator.base36_uuid }
    started_date    { Time.zone.today }
    ended_date      { started_date }
    last_ended_date { ended_date }
    # status          { :untreated }
    sequence(:memo) { |n| "memo(#{n})" }

    # :nocov:
    after(:build) do |task_event|
      if task_event.task_cycle.blank?
        task_event.space = FactoryBot.build(:space) if task_event.space.blank?
        task_event.task_cycle = FactoryBot.build(:task_cycle, space: task_event.space)
      else
        task_event.space = task_event.task_cycle.space
      end
    end
    after(:stub) do |task_event|
      if task_event.task_cycle.blank?
        task_event.space = FactoryBot.build_stubbed(:space) if task_event.space.blank?
        task_event.task_cycle = FactoryBot.build_stubbed(:task_cycle, space: task_event.space)
      else
        task_event.space = task_event.task_cycle.space
      end
    end
    # :nocov:

    # 開始・終了日
    trait :tommorow_start do
      started_date { Time.zone.today + 1.day }
      # ended_date   { started_date }
    end
    trait :yesterday_end do
      ended_date   { Time.zone.today - 1.day }
      started_date { ended_date }
    end
    trait :today_end do
      # ended_date   { Time.zone.today }
      # started_date { ended_date }
    end
    trait :tommorow_end do
      # started_date { Time.zone.today }
      ended_date { Time.zone.today + 1.day }
    end
    trait :update_end do
      last_ended_date { Time.zone.today + 3.days }
      ended_date      { Time.zone.today }
      started_date    { ended_date }
    end

    # ステータス
    trait :untreated do
      # status { :untreated }
    end
    trait :waiting_premise do
      status { :waiting_premise }
    end
    trait :processing do
      status { :processing }
    end
    trait :completed do
      status            { :complete }
      last_completed_at { 1.hour.ago }
    end

    # 担当
    trait :assigned do
      assigned_at { 2.hours.ago }
      association :assigned_user, factory: :user
    end
  end
end
