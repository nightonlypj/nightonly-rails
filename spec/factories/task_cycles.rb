FactoryBot.define do
  factory :task_cycle do
    cycle            { :weekly }
    # target           { nil }
    # month            { nil }
    # day              { nil }
    # business_day     { nil }
    # week             { nil }
    wday             { TaskCycle.wdays_i18n.keys[[0, 6].include?(Time.current.wday) ? 0 : Time.current.wday - 1].to_sym } # NOTE: 土・日曜日をコメントアウトしている為
    handling_holiday { TaskCycle.handling_holidays.keys[rand(2)].to_sym }
    period           { rand(1..3) }
    order            { 1 }

    # :nocov:
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
        task_cycle.task = FactoryBot.build_stubbed(:task, space: task_cycle.space)
      else
        task_cycle.space = task_cycle.task.space
      end
    end
    # :nocov:

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

    # 毎月/毎年 -> 日/営業日/週
    trait :day do
      target { :day }
      day    { Time.current.day }
      wday   { nil }
      # handling_holiday { %i[before after][rand(2)] }
    end
    trait :business_day do
      target           { :business_day }
      business_day     { [(Time.current.day * 5 / 7) + 1, 20].min }
      wday             { nil }
      handling_holiday { nil }
    end
    trait :week do
      target           { :week }
      week             { TaskCycle.weeks.keys[(Time.current.day - 1) / 7] }
      # wday             { TaskCycle.wdays_i18n.keys[[0, 6].include?(Time.current.wday) ? 0 : Time.current.wday - 1].to_sym } # NOTE: 土・日曜日をコメントアウトしている為
      # handling_holiday { %i[before after][rand(2)] }
    end

    # 論理削除
    trait :deleted do
      deleted_at { Time.current }
    end
  end
end
