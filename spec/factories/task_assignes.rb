FactoryBot.define do
  factory :task_assigne do
    # user_ids { nil }

    # :nocov:
    after(:build) do |task_assigne|
      if task_assigne.task.blank?
        task_assigne.space = FactoryBot.build(:space) if task_assigne.space.blank?
        task_assigne.task = FactoryBot.build(:task, space: task_assigne.space)
      else
        task_assigne.space = task_assigne.task.space
      end
    end
    after(:stub) do |task_assigne|
      if task_assigne.task.blank?
        task_assigne.space = FactoryBot.build_stubbed(:space) if task_assigne.space.blank?
        task_assigne.task = FactoryBot.build_stubbed(:task, space: task_assigne.space)
      else
        task_assigne.space = task_assigne.task.space
      end
    end
    # :nocov:
  end
end
