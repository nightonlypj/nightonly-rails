json.success true
json.notice notice if notice.present?

json.task do
  json.partial! '/tasks/task', task: @task, detail: true, current_member: @current_member

  json.cycles do
    json.array! @task.task_cycles_active do |task_cycle|
      json.partial! '/tasks/task_cycle', task_cycle:
    end
  end

  json.partial! '/tasks/task_assignes', task_assigne_user_ids: @task_assigne_user_ids, task_assigne_users: @task_assigne_users
end

json.event do
  json.partial! 'task_event', task: @task, task_event: @task_event, detail: true, current_member: @current_member
end

if @task_event.task_cycle.deleted_at.present?
  json.deleted_cycle do
    json.partial! '/tasks/task_cycle', task_cycle: @task_event.task_cycle
  end
end
