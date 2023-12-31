json.success true
json.notice notice if notice.present?

json.task do
  json.partial! 'task', task: @task, detail: @detail, current_member: @current_member

  json.cycles do
    json.array! @task.task_cycles_active do |task_cycle|
      json.partial! 'task_cycle', task_cycle:
    end
  end

  json.partial! 'task_assignes', task_assigne_user_ids: @task_assigne_user_ids, task_assigne_users: @task_assigne_users if @detail
end
