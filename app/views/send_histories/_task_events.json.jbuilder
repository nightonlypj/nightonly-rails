json.array! task_event_ids do |id|
  task_event = task_events[id.to_i]
  if task_event.blank?
    json.deleted true
    next
  end

  json.code task_event.code
  json.started_date l(task_event.started_date, format: :json)
  json.last_ended_date l(task_event.last_ended_date, format: :json)
  json.status task_event.status
  json.status_i18n task_event.status_i18n

  if task_event.assigned_user_id.present?
    json.assigned_user do
      json.partial! './users/auth/user', user: task_event.assigned_user, use_email: current_member&.power_admin? if task_event.assigned_user.present?
      json.deleted task_event.assigned_user.blank?
    end
  end

  json.task do
    json.priority task_event.task_cycle.task.priority
    json.priority_i18n task_event.task_cycle.task.priority_i18n
    json.title task_event.task_cycle.task.title
  end
end
