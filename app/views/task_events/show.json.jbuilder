json.success true
json.alert alert if alert.present?
json.notice notice if notice.present?

json.task do
  json.partial! './tasks/task', task: @task, use_add_info: true

  json.cycles do
    json.array! @task.task_cycles_active do |task_cycle|
      json.partial! './tasks/task_cycle', task_cycle: task_cycle
    end
  end
end

json.event do
  json.event_id @task_event.id
  json.cycle_id @task_event.task_cycle_id
  json.task_id @task_event.task_cycle.task_id
  json.start l(@task_event.started_date, format: :json)
  json.end l(@task_event.ended_date, format: :json) if @task_event.started_date != @task_event.ended_date
  json.status @task_event.status
  json.status_i18n @task_event.status_i18n
  json.memo @task_event.memo

  if @task_event.assigned_user_id.present?
    json.assigned_user do
      json.partial! './users/auth/user', user: @task_event.assigned_user, use_email: true if @task_event.assigned_user.present?
      json.deleted @task_event.assigned_user.blank?
    end
  end
  json.assigned_at l(@task_event.assigned_at, format: :json, default: nil)

  if @task_event.last_updated_user_id.present?
    json.last_updated_user do
      json.partial! './users/auth/user', user: @task_event.last_updated_user, use_email: true if @task_event.last_updated_user.present?
      json.deleted @task_event.last_updated_user.blank?
    end
  end
  json.last_updated_at l(@task_event.last_updated_at, format: :json, default: nil)
end
