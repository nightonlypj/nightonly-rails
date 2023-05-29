json.id send_history.id
json.target_date l(send_history.target_date, format: :json)

json.notice_target send_history.notice_target
json.notice_target_i18n send_history.notice_target_i18n
if send_history.notice_target_start?
  json.notice_start_hour send_history.send_setting.start_notice_start_hour
  json.notice_completed send_history.send_setting.start_notice_completed
  json.notice_required send_history.send_setting.start_notice_required
end
if send_history.notice_target_next?
  json.notice_start_hour send_history.send_setting.next_notice_start_hour
  json.notice_completed send_history.send_setting.next_notice_completed
  json.notice_required send_history.send_setting.next_notice_required
end

json.send_target send_history.send_target
json.send_target_i18n send_history.send_target_i18n
if detail && @current_member.present?
  if send_history.send_target_slack?
    json.slack do
      json.name send_history.send_setting.slack_domain.name
      json.webhook_url send_history.send_setting.slack_webhook_url
      json.mention send_history.send_setting.slack_mention
    end
  end
  if send_history.send_target_email?
    json.email do
      json.address send_history.send_setting.email_address
    end
  end
end

json.status send_history.status
json.status_i18n send_history.status_i18n
json.started_at l(send_history.started_at, format: :json)
json.completed_at l(send_history.completed_at, format: :json, default: nil)

json.target_count send_history.target_count
return unless detail

json.error_message send_history.error_message if @current_member.present?

json.next_task_events do
  json.partial! './send_histories/task_events', task_event_ids: @next_task_event_ids, task_events: @task_events
end
json.expired_task_events do
  json.partial! './send_histories/task_events', task_event_ids: @expired_task_event_ids, task_events: @task_events
end
json.end_today_task_events do
  json.partial! './send_histories/task_events', task_event_ids: @end_today_task_event_ids, task_events: @task_events
end
json.date_include_task_events do
  json.partial! './send_histories/task_events', task_event_ids: @date_include_task_event_ids, task_events: @task_events
end
json.complete_task_events do
  json.partial! './send_histories/task_events', task_event_ids: @completed_task_event_ids, task_events: @task_events
end
