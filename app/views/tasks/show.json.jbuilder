json.success true
json.task do
  json.partial! 'task', task: @task, detail: true

  json.cycles do
    json.array! @task.task_cycles_active do |task_cycle|
      json.partial! 'task_cycle', task_cycle: task_cycle
    end
  end
end
