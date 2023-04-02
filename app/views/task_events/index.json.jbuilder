json.success true
json.search_params do
  json.start_date l(@start_date, format: :json)
  json.end_date l(@end_date, format: :json)
end

json.space do
  json.partial! './spaces/space', space: @space

  if @current_member.present?
    json.current_member do
      json.power @current_member.power
      json.power_i18n @current_member.power_i18n
    end
  end
end

json.events do
  json.partial! 'events', task_events: @task_events, next_events: @next_events, task: nil
end

json.tasks do
  json.array! @tasks.each_value do |task|
    json.partial! './tasks/task', task: task, use_add_info: false
  end
end
