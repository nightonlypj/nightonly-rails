shared_context '通知設定作成' do
  let_it_be(:send_settings) do
    [
      FactoryBot.create(:send_setting, :slack, space:, deleted_at: Time.current),
      FactoryBot.create(:send_setting, :email, space:, deleted_at: Time.current),
      FactoryBot.create(:send_setting, :slack, :email, space:, deleted_at: nil)
    ]
  end
end

shared_context '通知履歴一覧作成' do |waiting_count, processing_count, success_count, skip_count, failure_count|
  let_it_be(:send_histories) do
    now = Time.current
    FactoryBot.create(:send_history, send_setting: other_send_setting) # NOTE: 対象外

    FactoryBot.create_list(:send_history, waiting_count, :start, :slack, :waiting, send_setting: send_settings[0], target_count: 4,
                                                                                   created_at: now - 4.days, updated_at: now - 5.days) +
      FactoryBot.create_list(:send_history, processing_count, :next, :email, :processing, send_setting: send_settings[1], target_count: 3,
                                                                                          created_at: now - 3.days, updated_at: now - 2.days) +
      FactoryBot.create_list(:send_history, success_count, :start, :slack, :success, send_setting: send_settings[2], target_count: 2,
                                                                                     created_at: now - 1.day, updated_at: now - 1.day) +
      FactoryBot.create_list(:send_history, skip_count, :next, :email, :skip, send_setting: send_settings[2], target_count: 1,
                                                                              created_at: now, updated_at: now) +
      FactoryBot.create_list(:send_history, failure_count, :next, :slack, :failure, send_setting: send_settings[2], target_count: 0,
                                                                                    created_at: now, updated_at: now)
  end
end

shared_context 'タスクイベント作成' do |next_count, expired_count, end_today_count, date_include_count, complete_count, add_deleted = false|
  let_it_be(:task_event_not) { FactoryBot.build_stubbed(:task_event) if add_deleted }
  let_it_be(:next_task_events) do
    next [] if next_count == 0

    task = FactoryBot.create(:task, :high, space:, created_user: space.created_user)
    task_cycles = FactoryBot.create_list(:task_cycle, next_count, task:)
    result = task_cycles.map { |task_cycle| FactoryBot.create(:task_event, :tommorow_start, task_cycle:) }
    result.push(id: task_event_not.id, deleted: true) if add_deleted

    result
  end
  let_it_be(:expired_task_events) do
    next [] if expired_count == 0

    task = FactoryBot.create(:task, :middle, space:, created_user: space.created_user)
    task_cycles = FactoryBot.create_list(:task_cycle, expired_count, task:)
    result = task_cycles.map { |task_cycle| FactoryBot.create(:task_event, :yesterday_end, :waiting_premise, :assigned, task_cycle:) }
    result.push(id: task_event_not.id, deleted: true) if add_deleted

    result
  end
  let_it_be(:end_today_task_events) do
    next [] if end_today_count == 0

    task = FactoryBot.create(:task, :low, space:, created_user: space.created_user)
    task_cycles = FactoryBot.create_list(:task_cycle, end_today_count, task:)
    result = task_cycles.map { |task_cycle| FactoryBot.create(:task_event, :today_end, :processing, :assigned, task_cycle:) }
    result.push(id: task_event_not.id, deleted: true) if add_deleted

    result
  end
  let_it_be(:date_include_task_events) do
    next [] if date_include_count == 0

    task = FactoryBot.create(:task, :none, space:, created_user: space.created_user)
    task_cycles = FactoryBot.create_list(:task_cycle, date_include_count, task:)
    result = task_cycles.map { |task_cycle| FactoryBot.create(:task_event, :update_end, task_cycle:) }
    result.push(id: task_event_not.id, deleted: true) if add_deleted

    result
  end
  let_it_be(:completed_task_events) do
    next [] if complete_count == 0

    task_cycles = FactoryBot.create_list(:task_cycle, complete_count, space:)
    result = task_cycles.map { |task_cycle| FactoryBot.create(:task_event, :today_end, :completed, :assigned, task_cycle:) }
    result.push(id: task_event_not.id, deleted: true) if add_deleted

    result
  end
end

# テスト内容（共通）
def expect_send_history_json(response_json_send_history, send_history, member, use = { detail: false })
  result = 14
  expect(response_json_send_history['id']).to eq(send_history.id)
  expect(response_json_send_history['target_date']).to eq(I18n.l(send_history.target_date, format: :json))

  expect(response_json_send_history['notice_target']).to eq(send_history.notice_target)
  expect(response_json_send_history['notice_target_i18n']).to eq(send_history.notice_target_i18n)
  expect(response_json_send_history['notice_start_hour']).to eq(send_history.send_setting["#{send_history.notice_target}_notice_start_hour"])
  expect(response_json_send_history['notice_completed']).to eq(send_history.send_setting["#{send_history.notice_target}_notice_completed"])
  expect(response_json_send_history['notice_required']).to eq(send_history.send_setting["#{send_history.notice_target}_notice_required"])

  expect(response_json_send_history['send_target']).to eq(send_history.send_target)
  expect(response_json_send_history['send_target_i18n']).to eq(send_history.send_target_i18n)
  if use[:detail] && member.present?
    data = response_json_send_history['slack']
    if send_history.send_target_slack?
      expect(data['name']).to eq(send_history.send_setting.slack_domain.name)
      expect(data['webhook_url']).to eq(send_history.send_setting.slack_webhook_url)
      expect(data['mention']).to eq(send_history.send_setting.slack_mention)
      expect(data.count).to eq(3)
      result += 1
    else
      expect(data).to be_nil
    end
    data = response_json_send_history['email']
    if send_history.send_target_email?
      expect(data['address']).to eq(send_history.send_setting.email_address)
      expect(data.count).to eq(1)
      result += 1
    else
      expect(data).to be_nil
    end
  end

  expect(response_json_send_history['status']).to eq(send_history.status)
  expect(response_json_send_history['status_i18n']).to eq(send_history.status_i18n)
  expect(response_json_send_history['started_at']).to eq(I18n.l(send_history.started_at, format: :json))
  expect(response_json_send_history['completed_at']).to eq(I18n.l(send_history.completed_at, format: :json, default: nil))

  expect(response_json_send_history['target_count']).to eq(send_history.target_count)

  if use[:detail]
    if member.present?
      expect(response_json_send_history['error_message']).to eq(send_history.error_message)
      result += 1
    end

    data = response_json_send_history['next_task_events']
    if send_history.notice_target_next?
      expect_task_events_json(data, next_task_events)
      result += 1
    else
      expect(data).to be_nil
    end
    expect_task_events_json(response_json_send_history['expired_task_events'], expired_task_events)
    expect_task_events_json(response_json_send_history['end_today_task_events'], end_today_task_events)
    expect_task_events_json(response_json_send_history['date_include_task_events'], date_include_task_events)
    expect_task_events_json(response_json_send_history['completed_task_events'], completed_task_events)
    result += 4
  end

  result
end

def expect_task_events_json(response_json_task_events, task_events)
  expect(response_json_task_events.count).to eq(task_events.count)
  response_json_task_events.each_with_index do |response_json_task_event, index|
    task_event = task_events[index]
    if task_event[:deleted]
      expect(response_json_task_event['deleted']).to eq(true)
      expect(response_json_task_event.count).to eq(1)
      next
    end

    result = 6
    expect(response_json_task_event['code']).to eq(task_event.code)
    expect(response_json_task_event['started_date']).to eq(I18n.l(task_event.started_date, format: :json))
    expect(response_json_task_event['last_ended_date']).to eq(I18n.l(task_event.last_ended_date, format: :json))
    expect(response_json_task_event['status']).to eq(task_event.status)
    expect(response_json_task_event['status_i18n']).to eq(task_event.status_i18n)

    data = response_json_task_event['assigned_user']
    if task_event.assigned_user_id.present?
      count = expect_user_json(data, task_event.assigned_user, { email: true })
      expect(data['deleted']).to eq(task_event.assigned_user.blank?)
      expect(data.count).to eq(count + 1)
      result += 1
    else
      expect(data).to be_nil
    end

    data = response_json_task_event['task']
    expect(data['priority']).to eq(task_event.task_cycle.task.priority)
    expect(data['priority_i18n']).to eq(task_event.task_cycle.task.priority_i18n)
    expect(data['title']).to eq(task_event.task_cycle.task.title)
    expect(data.count).to eq(3)

    expect(response_json_task_event.count).to eq(result)
  end
end
