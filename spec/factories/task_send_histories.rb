FactoryBot.define do
  factory :task_send_history do
    notice_target { :today }
    send_target   { :slack }
    target_date   { Time.current.to_date }
    sended_at     { Time.current }
    send_result   { :success }
    sended_data   { '送信内容' }

    after(:build) do |task_send_history|
      if task_send_history.task_send_setting.blank?
        task_send_history.space = FactoryBot.build(:space) if task_send_history.space.blank?
        task_send_history.task_send_setting = FactoryBot.build(:task_send_setting, space: task_send_history.space)
      else
        task_send_history.space = task_send_history.task_send_setting.space
      end
    end
    after(:stub) do |task_send_history|
      if task_send_history.task_send_setting.blank?
        task_send_history.space = FactoryBot.build_stubbed(:space) if task_send_history.space.blank?
        task_send_history.task_send_setting = FactoryBot.build_stubbed(:task, space: task_send_history.space) if task_send_history.task_send_setting.blank?
      else
        task_send_history.space = task_send_history.task_send_setting.space
      end
    end

    # 通知対象
    trait :today do
      # notice_target { :today }
    end
    trait :next do
      notice_target { :next }
    end

    # 送信結果
    trait :success do
      # send_result { :success }
    end
    trait :failure do
      send_result   { :failure }
      error_message { 'エラー内容' }
    end

    # 送信対象
    trait :slack do
      # send_target { :slack }
    end
    trait :email do
      send_target { :email }
    end
  end
end
