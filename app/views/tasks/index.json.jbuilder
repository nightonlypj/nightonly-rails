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

json.task do
  json.total_count @tasks.total_count
  json.current_page @tasks.current_page
  json.total_pages @tasks.total_pages
  json.limit_value @tasks.limit_value
end
json.tasks do
  json.array! @tasks do |task|
    json.partial! 'task', task: task, detail: false

    json.cycles do
      task_cycles = task.task_cycles_active.index_by do |task_cycle|
        "#{task_cycle.order}_#{task_cycle.updated_at.strftime('%Y%m%d%H%M%S')}_#{task_cycle.id}"
      end.sort # NOTE: DBアクセスせずに、並び順で出力

      json.array! task_cycles do |_, task_cycle|
        json.partial! 'task_cycle', task_cycle: task_cycle
      end
    end
  end
end
