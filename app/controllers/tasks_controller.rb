class TasksController < ApplicationAuthController
  include TasksConcern
  include TaskCyclesConcern
  before_action :response_not_acceptable_for_not_api
  before_action :set_space_current_member_auth_private
  before_action :response_api_for_user_destroy_reserved, only: %i[create update destroy]
  before_action :check_power, only: %i[create update destroy]
  before_action :set_task, only: %i[show update]
  before_action :set_params_index, only: :index
  before_action :validate_params_create, only: :create
  before_action :validate_params_update, only: :update

  # GET /tasks/:space_code(.json) タスク一覧API
  def index
    @tasks = tasks_search.page(params[:page]).per(Settings.default_tasks_limit)
  end

  # GET /tasks/:space_code/detail/:id(.json) タスク詳細API
  def show; end

  # POST /tasks/:space_code/create(.json) タスク追加API(処理)
  def create
    ActiveRecord::Base.transaction do
      @task.save!
      if @insert_task_cycles.present?
        insert_task_cycles = @insert_task_cycles.map { |insert_task_cycle| insert_task_cycle.merge(task_id: @task.id) }
        TaskCycle.insert_all!(insert_task_cycles)
      end
    end

    render_success('notice.task.create', :created)
  end

  # POST /tasks/:space_code/update/:id(.json) タスク設定変更API(処理)
  def update
    if @task.changed? || @insert_task_cycles.present? || @delete_task_cycle_ids.present?
      ActiveRecord::Base.transaction do
        @task.update!(last_updated_user: current_user, updated_at: @now)
        TaskCycle.insert_all!(@insert_task_cycles) if @insert_task_cycles.present?
        TaskCycle.where(id: @delete_task_cycle_ids).update_all(deleted_at: @now, updated_at: @now) if @delete_task_cycle_ids.present? # TODO: 未使用なら物理削除
      end
    end

    render_success('notice.task.update')
  end

  # POST /tasks/:space_code/delete/:id(.json) タスク削除API(処理)
  def destroy
    # TODO
  end

  private

  def render_success(notice, status = nil)
    set_task(@task.id)
    return render :show_index, locals: { notice: t(notice) }, status: status if @months.blank?

    set_holidays(@start_date - 2.month, @end_date) # NOTE: 期間が20営業日でも1ヶ月を超える場合がある為

    business_date = handling_holiday_date(Time.current.to_date.tomorrow, :after)
    if @start_date <= business_date
      @task_events = TaskEvent.joins(:task_cycle).where(space: @space, task_cycle: { task_id: @task.id }).by_month(@months, business_date).order(:id)
    else
      @task_events = []
    end

    @next_events = []
    @task_event_exists = @task_events.map { |task_event| [{ task_cycle_id: task_event.task_cycle_id, ended_date: task_event.ended_date }, true] }.to_h
    logger.debug("@task_event_exists: #{@task_event_exists}")

    next_start_date = [@start_date, Time.current.to_date].max
    @task.task_cycles_active.each do |task_cycle|
      cycle_set_next_events(task_cycle, @task, next_start_date, @end_date)
    end

    render :show_events, locals: { notice: t(notice) }, status: status
  end

  # Use callbacks to share common setup or constraints between actions.
  def validate_params_create
    @task = Task.new(task_params.merge(space: @space, created_user: current_user))
    check_validation(:create)
  end

  def validate_params_update
    @task.assign_attributes(task_params)
    check_validation(:update)
  end

  def check_validation(target)
    @task.valid?

    @now = Time.current
    check_validation_cycles(params[:task][:cycles], target)
    check_validation_months(params[:months])

    render './failure', locals: { errors: @task.errors, alert: t('errors.messages.not_saved.other') }, status: :unprocessable_entity if @task.errors.any?
  end

  def check_validation_cycles(cycles, target)
    cycle_error = 0
    use_task_cycle_keys = {}
    exist_task_cycles = target == :create ? {} : @task.task_cycles_active.index_by { |task_cycle| task_cycle_key(task_cycle) }
    @insert_task_cycles = []
    active_task_cycle_ids = []
    cycles.each.with_index(1) do |task_cycle, index|
      next if task_cycle[:delete].present? && task_cycle[:delete] == true

      task_cycle = TaskCycle.new(task_cycle_params(task_cycle).merge(space: @space, task: @task))
      if task_cycle.invalid?
        task_cycle.errors.each do |error|
          @task.errors.add("cycle#{index}_#{error.attribute}".to_sym, error.message)
          cycle_error += 1
        end
        next
      end

      key = task_cycle_key(task_cycle)
      if use_task_cycle_keys[key].present?
        @task.errors.add("cycle#{index}_cycle", t('errors.messages.task_cycles.not_unique'))
        cycle_error += 1
        next
      end
      use_task_cycle_keys[key] = index

      if exist_task_cycles[key].blank?
        @insert_task_cycles.push(task_cycle.attributes.symbolize_keys.merge(created_at: @now, updated_at: @now))
      else
        active_task_cycle_ids.push(exist_task_cycles[key].id)
      end
    end
    @delete_task_cycle_ids = exist_task_cycles.values.pluck(:id) - active_task_cycle_ids

    if cycle_error.zero?
      count = @insert_task_cycles.count + active_task_cycle_ids.count
      @task.errors.add(:cycles, t('errors.messages.task_cycles.zero')) if count.zero?
      @task.errors.add(:cycles, t('errors.messages.task_cycles.max_count', count: Settings.task_cycles_max_count)) if count > Settings.task_cycles_max_count
    end
  end

  def task_cycle_key(task_cycle)
    {
      cycle: task_cycle.cycle,
      month: task_cycle.month,
      day: task_cycle.day,
      business_day: task_cycle.business_day,
      week: task_cycle.week,
      wday: task_cycle.wday,
      handling_holiday: task_cycle.handling_holiday,
      period: task_cycle.period
    }
  end

  def check_validation_months(months)
    @months = months
    return if @months.blank?

    @months = @months.compact.uniq.sort
    @months.each do |month|
      valid = month.length == 6
      valid = false if valid && get_date(month).blank?
      @task.errors.add(:months, t('errors.messages.task.months.invalid', month: month)) unless valid
    end
    return if @task.errors.any?

    @start_date = get_date(@months.first)
    @end_date = get_date(@months.last).end_of_month
  end

  def get_date(month)
    "#{month}01".to_date
  rescue StandardError
    nil
  end

  # Only allow a list of trusted parameters through.
  def task_params
    params[:task] = Task.new.attributes if params[:task].blank? # NOTE: 変更なしで成功する為
    params[:task][:priority] = nil if Task.priorities[params[:task][:priority]].blank? # NOTE: ArgumentError対策

    params[:task][:summary] = params[:task][:summary]&.gsub(/\R/, "\n") # NOTE: 改行コードを統一
    params[:task][:premise] = params[:task][:premise]&.gsub(/\R/, "\n")
    params[:task][:process] = params[:task][:process]&.gsub(/\R/, "\n")

    params.require(:task).permit(:priority, :title, :summary, :premise, :process, :started_date, :ended_date)
  end

  def task_cycle_params(task_cycle)
    # NOTE: ArgumentError対策
    task_cycle[:cycle]            = nil if TaskCycle.cycles[task_cycle[:cycle]].blank?
    task_cycle[:target]           = nil if TaskCycle.targets[task_cycle[:target]].blank?
    task_cycle[:week]             = nil if TaskCycle.weeks[task_cycle[:week]].blank?
    task_cycle[:wday]             = nil if TaskCycle.wdays[task_cycle[:wday]].blank?
    task_cycle[:handling_holiday] = nil if TaskCycle.handling_holidays[task_cycle[:handling_holiday]].blank?

    cycle = task_cycle[:cycle]&.to_sym
    target = task_cycle[:target]&.to_sym

    keys = [:cycle]
    keys += [:month] if cycle == :yearly
    if %i[monthly yearly].include?(cycle)
      keys += [:target]
      keys += [:day] if target == :day
      keys += [:business_day] if target == :business_day
      keys += [:week] if target == :week
    end
    keys += [:wday] if cycle == :weekly || (%i[monthly yearly].include?(cycle) && target == :week)
    keys += [:handling_holiday] if cycle == :weekly || (%i[monthly yearly].include?(cycle) && %i[day week].include?(target))

    task_cycle.permit(keys + [:period])
  end
end
