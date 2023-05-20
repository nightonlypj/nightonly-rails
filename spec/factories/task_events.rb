FactoryBot.define do
  factory :task_event do
    code            { Digest::MD5.hexdigest(SecureRandom.uuid).to_i(16).to_s(36).rjust(25, '0') }
    started_date    { Time.current.to_date }
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
        task_event.task_cycle = FactoryBot.build_stubbed(:task, space: task_event.space)
      else
        task_event.space = task_event.task_cycle.space
      end
    end
    # :nocov:

    # 開始・終了日
    trait :yesterday do
      started_date    { Time.current.yesterday.to_date }
      ended_date      { Time.current.to_date }
    end

    # ステータス
    trait :completed do
      status            { :complete }
      last_completed_at { Time.current }
    end

    # 担当
    trait :assigned do
      assigned_at { Time.current }
      association :assigned_user, factory: :user
    end
  end
end
