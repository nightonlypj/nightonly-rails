json.success true
json.search_params do
  json.text @text
  json.priority @priorities.join(',')
  json.before @before ? 1 : 0
  json.active @active ? 1 : 0
  json.after @after ? 1 : 0
  json.sort @sort
  json.desc @desc ? 1 : 0
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

json.task do
  json.total_count @tasks.total_count
  json.current_page @tasks.current_page
  json.total_pages @tasks.total_pages
  json.limit_value @tasks.limit_value
end
json.tasks do
  json.array! @tasks do |task|
    json.partial! 'task', task: task

    json.cycles do
      json.array! task.task_cycles do |task_cycle|
        json.partial! 'task_cycle', task_cycle: task_cycle
      end
    end

    if task.created_user_id.present?
      json.created_user do
        json.partial! './users/auth/user', user: task.created_user, use_email: true if task.created_user.present?
        json.deleted task.created_user.blank?
      end
    end
    json.created_at l(task.created_at, format: :json)

    if task.last_updated_user_id.present?
      json.last_updated_user do
        json.partial! './users/auth/user', user: task.last_updated_user, use_email: true if task.last_updated_user.present?
        json.deleted task.last_updated_user.blank?
      end
    end
    json.last_updated_at l(task.last_updated_at, format: :json, default: nil)
  end
end
