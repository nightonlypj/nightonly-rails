FactoryBot.define do
  factory :send_history do
    notice_target { :start }
    send_target   { :slack }
    target_date   { Time.current.to_date }
    sended_at     { Time.current }
    send_result   { :success }
    sended_data   { '送信内容' }

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

    # 通知対象
    trait :start do
      # notice_target { :start }
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
