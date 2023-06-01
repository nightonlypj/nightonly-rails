# テスト内容（共通）
def expect_send_setting_json(response_json_send_setting, send_setting, member)
  result = 4

  count = 1
  data = response_json_send_setting['slack']
  expect(data['enabled']).to eq(send_setting.blank? ? false : send_setting.slack_enabled)
  if send_setting.present? && member.present?
    expect(data['name']).to eq(send_setting.slack_domain&.name)
    expect(data['webhook_url']).to eq(send_setting.slack_webhook_url)
    expect(data['mention']).to eq(send_setting.slack_mention)
    count += 3
  end
  expect(data.count).to eq(count)

  count = 1
  data = response_json_send_setting['email']
  expect(data['enabled']).to eq(send_setting.blank? ? false : send_setting.email_enabled)
  if send_setting.present? && member.present?
    expect(data['address']).to eq(send_setting.email_address)
    count += 1
  end
  expect(data.count).to eq(count)

  data = response_json_send_setting['start_notice']
  expect(data['start_hour']).to eq(send_setting.blank? ? Settings.default_start_notice_start_hour : send_setting.start_notice_start_hour)
  expect(data['completed']).to eq(send_setting.blank? ? Settings.default_start_notice_completed : send_setting.start_notice_completed)
  expect(data['required']).to eq(send_setting.blank? ? Settings.default_start_notice_required : send_setting.start_notice_required)
  expect(data.count).to eq(3)

  data = response_json_send_setting['next_notice']
  expect(data['start_hour']).to eq(send_setting.blank? ? Settings.default_next_notice_start_hour : send_setting.next_notice_start_hour)
  expect(data['completed']).to eq(send_setting.blank? ? Settings.default_next_notice_completed : send_setting.next_notice_completed)
  expect(data['required']).to eq(send_setting.blank? ? Settings.default_next_notice_required : send_setting.next_notice_required)
  expect(data.count).to eq(3)

  data = response_json_send_setting['last_updated_user']
  if send_setting&.last_updated_user_id.present?
    count = expect_user_json(data, send_setting.last_updated_user, { email: true })
    expect(data['deleted']).to eq(send_setting.last_updated_user.blank?)
    expect(data.count).to eq(count + 1)
    result += 1
  else
    expect(data).to be_nil
  end
  data = response_json_send_setting['last_updated_at']
  if send_setting.present?
    expect(data).to eq(I18n.l(send_setting.updated_at, format: :json))
    result += 1
  else
    expect(data).to be_nil
  end

  result
end
