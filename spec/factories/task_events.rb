FactoryBot.define do
  factory :task_event do
    started_date { Time.current.to_date }
    ended_date   { (Time.current + 1.day).to_date }
    # status       { :untreated }
    sequence(:memo) { |n| "memo(#{n})" }
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
        task_event.task_cycle = FactoryBot.build_stubbed(:task, space: task_event.space) if task_event.task_cycle.blank?
      else
        task_event.space = task_event.task_cycle.space
      end
    end
  end
end
