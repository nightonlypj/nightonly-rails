json.success true
json.alert alert if alert.present?
json.notice notice if notice.present?

json.task do
  json.partial! 'task', task: @task

  json.cycles do
    json.array! @task.task_cycles_active do |task_cycle|
      json.partial! 'task_cycle', task_cycle: task_cycle
    end
  end
end
