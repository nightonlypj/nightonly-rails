FactoryBot.define do
  factory :task_cycle do
    cycle            { :weekly }
    # month            { nil }
    # day              { nil }
    # business_day     { nil }
    # week             { nil }
    wday             { Time.current.wday }
    handling_holiday { %i[before after][rand(2)] }
    period           { rand(1..3) }
    after(:build) do |task_cycle|
      if task_cycle.task.blank?
        task_cycle.space = FactoryBot.build(:space) if task_cycle.space.blank?
        task_cycle.task = FactoryBot.build(:task, space: task_cycle.space)
      else
        task_cycle.space = task_cycle.task.space
      end
    end
    after(:stub) do |task_cycle|
      if task_cycle.task.blank?
        task_cycle.space = FactoryBot.build_stubbed(:space) if task_cycle.space.blank?
        task_cycle.task = FactoryBot.build_stubbed(:task, space: task_cycle.space) if task_cycle.task.blank?
      else
        task_cycle.space = task_cycle.task.space
      end
    end

    # 周期
    trait :weekly do
      # cycle { :weekly }
    end
    trait :monthly do
      cycle { :monthly }
    end
    trait :yearly do
      cycle { :yearly }
      month { Time.current.month }
    end

    # 年次/月次 -> 日/営業日/週
    trait :day do
      day  { Time.current.day }
      wday { nil }
      # handling_holiday { %i[before after][rand(2)] }
    end
    trait :business_day do
      business_day     { [(Time.current.day * 5 / 7) + 1, 20].min }
      wday             { nil }
      handling_holiday { nil }
    end
    trait :week do
      week { (Time.current.day + 6) / 7 }
      # wday { Time.current.wday }
      # handling_holiday { %i[before after][rand(2)] }
    end
  end
end
