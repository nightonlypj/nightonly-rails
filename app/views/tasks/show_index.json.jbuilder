json.success true
json.notice notice

json.task do
  json.partial! 'task', task: @task, detail: @detail, current_member: @current_member

  json.cycles do
    json.array! @task.task_cycles_active do |task_cycle|
      json.partial! 'task_cycle', task_cycle:
    end
  end
end
