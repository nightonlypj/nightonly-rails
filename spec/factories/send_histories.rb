FactoryBot.define do
  factory :send_history do
    # status        { :waiting }
    started_at    { Time.current }
    notice_target { :start }
    send_target   { :slack }
    target_date   { Time.current.to_date }

    after(:build) do |send_history|
      if send_history.send_setting.blank?
        send_history.space = FactoryBot.build(:space) if send_history.space.blank?
        send_history.send_setting = FactoryBot.build(:send_setting, space: send_history.space)
      else
        send_history.space = send_history.send_setting.space
      end
    end
    after(:stub) do |send_history|
      if send_history.send_setting.blank?
        send_history.space = FactoryBot.build_stubbed(:space) if send_history.space.blank?
        send_history.send_setting = FactoryBot.build_stubbed(:task, space: send_history.space) if send_history.send_setting.blank?
      else
        send_history.space = send_history.send_setting.space
      end
    end

    # ステータス
    trait :waiting do
      # status { :waiting }
    end
    trait :processing do
      status { :processing }
    end
    trait :success do
      status       { :success }
      completed_at { Time.current }
      sended_data  { '送信内容' }
    end
    trait :skip do
      status       { :skip }
      completed_at { Time.current }
    end
    trait :failure do
      status        { :failure }
      completed_at  { Time.current }
      error_message { 'エラー内容' }
    end

    # 通知対象
    trait :start do
      # notice_target { :start }
    end
    trait :next do
      notice_target { :next }
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
