# テスト内容（共通）
def expect_task_event_json(response_json_event, task, task_cycle, task_event, expect_event, use = { detail: false })
  result = 3
  if task_event.present?
    expect(response_json_event['code']).to eq(task_event.code)
    result += 1
  end
  expect(response_json_event['cycle_id']).to eq(task_cycle.id)
  expect(response_json_event['task_id']).to eq(task.id)
  expect(response_json_event['priority_order']).to eq(Settings.priority_order[task.priority])
  if task_event.present?
    expect(response_json_event['started_date']).to eq(I18n.l(task_event.started_date, format: :json))
    expect(response_json_event['last_ended_date']).to eq(I18n.l(task_event.last_ended_date, format: :json))
    expect(response_json_event['status']).to eq(task_event.status)
    expect(response_json_event['status_i18n']).to eq(task_event.status_i18n)
    result += 4
  else
    expect(response_json_event['started_date']).to eq(expect_event[:started_date])
    expect(response_json_event['last_ended_date']).to eq(expect_event[:last_ended_date])
    result += 2
  end

  if use[:detail]
    result += 4
    expect(response_json_event['last_completed_at']).to eq(I18n.l(task_event.last_completed_at, format: :json, default: nil))

    data = response_json_event['assigned_user']
    if task_event.assigned_user_id.present?
      count = task_event.assigned_user.present? ? expect_user_json(data, task_event.assigned_user, { email: true }) : 0
      expect(data['deleted']).to eq(task_event.assigned_user.blank?)
      expect(data.count).to eq(count + 1)
      result += 1
    else
      expect(data).to be_nil
    end
    expect(response_json_event['assigned_at']).to eq(I18n.l(task_event.assigned_at, format: :json, default: nil))

    expect(response_json_event['memo']).to eq(task_event.memo)

    data = response_json_event['last_updated_user']
    if task_event.last_updated_user_id.present?
      count = task_event.last_updated_user.present? ? expect_user_json(data, task_event.last_updated_user, { email: true }) : 0
      expect(data['deleted']).to eq(task_event.last_updated_user.blank?)
      expect(data.count).to eq(count + 1)
      result += 1
    else
      expect(data).to be_nil
    end
    expect(response_json_event['last_updated_at']).to eq(I18n.l(task_event.last_updated_at, format: :json, default: nil))
  end

  result
end
