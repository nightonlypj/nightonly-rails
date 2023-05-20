module TasksConcern
  extend ActiveSupport::Concern

  private

  def set_task(id = params[:id])
    @task = Task.where(space: @space, id: id).eager_load(:task_cycles_active, :created_user, :last_updated_user)
                .merge(TaskCycle.order(:order, :updated_at, :id)).first
    response_not_found if @task.blank?
  end

  SORT_COLUMN = {
    'priority' => 'tasks.priority',
    'title' => 'tasks.title',
    'cycles' => 'task_cycles.cycle',
    'started_date' => 'tasks.started_date',
    'ended_date' => 'tasks.ended_date',
    'created_user.name' => 'users.name',
    'created_at' => 'tasks.created_at',
    'last_updated_user.name' => 'last_updated_users_tasks.name',
    'last_updated_at' => 'tasks.updated_at'
  }.freeze

  def get_value(task, output_item)
    # TODO
  end

  def set_params_index(search_params = params, sort_only = false)
    @priorities = []
    if sort_only
      @text = nil

      Task.priorities.each do |key, _value|
        @priorities.push(key)
      end
      @before = true
      @active = true
      @after = false
    else
      @text = search_params[:text]&.slice(..(255 - 1))

      Task.priorities.each do |key, _value|
        @priorities.push(key) if priority_include_key?(search_params[:priority], key)
      end
      @before = params[:before] != '0'
      @active = params[:active] != '0'
      @after = params[:after] == '1'
    end

    @sort = SORT_COLUMN.include?(search_params[:sort]) ? search_params[:sort] : 'started_date'
    @desc = search_params[:desc] != '0'
  end

  def priority_include_key?(priority, key)
    priority.blank? ? priority.nil? : priority.split(',').include?(key)
  end

  def tasks_select(codes)
    # TODO
  end

  def tasks_search
    Task.where(space: @space).search(@text).by_priority(@priorities).by_start_end_date(@before, @active, @after)
        .eager_load(:task_cycles_active, :created_user, :last_updated_user)
        .order(SORT_COLUMN[@sort] + (@desc ? ' DESC' : ''), id: :desc)
    # .merge(TaskCycle.order(:order, :updated_at, :id)) # NOTE: ページの最後のtaskにtask_cycleが複数紐付く場合、次ページでの取得になる為
  end

  # ダウンロードファイルのデータ作成
  def task_file_data(output_items)
    # TODO
  end
end
