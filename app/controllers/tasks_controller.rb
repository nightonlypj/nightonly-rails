class TasksController < ApplicationAuthController
  include TasksConcern
  before_action :response_not_acceptable_for_not_api
  before_action :set_space_current_member
  before_action :response_api_for_user_destroy_reserved, only: %i[create update destroy]
  before_action :check_power, only: %i[create update destroy]
  before_action :set_task, only: %i[show update]
  before_action :set_params_index, only: :index
  before_action :set_params_events, only: :events
  before_action :validate_params_create, only: :create
  before_action :validate_params_update, only: :update

  # GET /tasks/:space_code(.json) タスク一覧API
  def index
    @tasks = tasks_search.page(params[:page]).per(Settings.default_tasks_limit)
  end

  # GET /tasks/:space_code/events(.json) タスクイベント一覧API
  def events
    @tasks = {}
    @next_events = []
    @next_start_date = [@start_date, Time.current.to_date].max # TODO: 一旦、当日以降。通知用を作ったらその次の日
    return if @next_start_date > @end_date

    @holidays = Holiday.where(date: (@next_start_date - 1.month)..@end_date).index_by(&:date) # NOTE: 期間(task_cycles.period)が1ヶ月以下の前提
    before_count = 0
    task_cycles = TaskCycle.active.where(space: @space).by_month(cycle_months + [nil])
                           .eager_load(:task).by_task_period(@next_start_date, @end_date).merge(Task.order(:priority, :id))
    task_cycles.each do |task_cycle|
      cycle_set_next_events(task_cycle, task_cycle.task)

      if before_count != @next_events.count
        @tasks[task_cycle.task_id] = task_cycle.task if @tasks[task_cycle.task_id].blank?
        before_count = @next_events.count
      end
    end
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

  def cycle_months
    return [*@next_start_date.month..@end_date.month] if @next_start_date.year == @end_date.year
    return [*@next_start_date.month..12, *1..@end_date.month].uniq.sort if @next_start_date.year == @end_date.year + 1

    [*1..12]
  end

  def render_success(notice, status = nil)
    set_task(@task.id)
    return render :show_index, locals: { notice: t(notice) }, status: status if params[:months].blank?

    months = params[:months].sort
    @next_events = []

    @next_start_date = [Time.new(months.first[0, 4], months.first[4, 2], 1).to_date, Time.current.to_date].max # TODO: 一旦、当日以降。通知用を作ったらその次の日
    @end_date = Time.new(months.last[0, 4], months.last[4, 2], 31).to_date
    @end_date = (@end_date - 1.month).end_of_month if @end_date.day != 31 # NOTE: 存在しない日付は丸められる為

    @holidays = Holiday.where(date: (@next_start_date - 1.month)..@end_date).index_by(&:date) # NOTE: 期間(task_cycles.period)が1ヶ月以下の前提
    @task.task_cycles_active.each do |task_cycle|
      cycle_set_next_events(task_cycle, @task, months)
    end

    render :show_events, locals: { notice: t(notice) }, status: status
  end

  def cycle_set_next_events(task_cycle, task, months = nil)
    start_date = [@next_start_date, task.started_date].max
    end_date = [@end_date, task.ended_date].compact.min

    case task_cycle.cycle.to_sym
    when :weekly
      weekly_set_next_events(task_cycle, start_date, end_date, months)
    when :monthly
      monthly_set_next_events(task_cycle, start_date, end_date, months)
    when :yearly
      yearly_set_next_events(task_cycle, start_date, end_date, months)
    else
      # :nocov:
      raise "task_cycle.cycle not found.(#{task_cycle.cycle})[id: #{task_cycle.id}]"
      # :nocov:
    end
  end

  def weekly_set_next_events(task_cycle, start_date, end_date, months)
    date = start_date + ((task_cycle.wday_before_type_cast - start_date.wday) % 7).days
    while date <= end_date # NOTE: 終了日が期間内のもの。開始日のみ期間内のものは含まれない。期間(task_cycles.period)が1ヶ月以下の前提
      set_next_events(date, task_cycle, start_date) if months.blank? || months.include?(date.strftime('%Y%m'))
      date += 1.week
    end
  end

  def monthly_set_next_events(task_cycle, start_date, end_date, months)
    month = start_date.beginning_of_month
    while month <= end_date # NOTE: 終了日が期間内のもの。開始日のみ期間内のものは含まれない。期間(task_cycles.period)が1ヶ月以下の前提
      target_set_next_events(month, task_cycle, start_date) if months.blank? || months.include?(month.strftime('%Y%m'))
      month += 1.month
    end
  end

  def yearly_set_next_events(task_cycle, start_date, end_date, months)
    month = start_date.beginning_of_month
    while month <= end_date # NOTE: 終了日が期間内のもの。開始日のみ期間内のものは含まれない。期間(task_cycles.period)が1ヶ月以下の前提
      if month.month == task_cycle.month
        target_set_next_events(month, task_cycle, start_date) if months.blank? || months.include?(month.strftime('%Y%m'))
        break if month.year >= end_date.year
      end
      month += 1.month
    end
  end

  def target_set_next_events(month, task_cycle, start_date)
    case task_cycle.target&.to_sym
    when :day
      day_set_next_events(month, task_cycle, start_date)
    when :business_day
      business_day_set_next_events(month, task_cycle, start_date)
    when :week
      week_set_next_events(month, task_cycle, start_date)
    else
      # :nocov:
      raise "task_cycle.target not found.(#{task_cycle.target})[id: #{task_cycle.id}]"
      # :nocov:
    end
  end

  def day_set_next_events(month, task_cycle, start_date)
    date = month + (task_cycle.day - 1).days
    date = (date - 1.month).end_of_month if date.day != task_cycle.day # NOTE: 存在しない日付は丸められる為
    set_next_events(date, task_cycle, start_date)
  end

  def business_day_set_next_events(month, task_cycle, start_date)
    date = month.end_of_month
    if task_cycle.business_day < date.day # NOTE: 最終営業日は月末（後続処理で休日の場合は前日）
      count = 0
      date = month
      loop do
        count += 1 unless holiday?(date)
        break if count == task_cycle.business_day
        break if date >= month.end_of_month

        date += 1.day
      end
    end
    set_next_events(date, task_cycle, start_date)
  end

  def week_set_next_events(month, task_cycle, start_date)
    date = month + ((task_cycle.wday_before_type_cast - month.wday) % 7).days + ((task_cycle.week_before_type_cast - 1) * 7).days
    date -= 7.days while date.month > month.month
    set_next_events(date, task_cycle, start_date)
  end

  def set_next_events(date, task_cycle, start_date)
    event_end_date = handling_end_date(date, task_cycle.handling_holiday)
    return if event_end_date < start_date

    event_start_date = end_to_start_date(event_end_date, task_cycle.period)
    @next_events.push([task_cycle, event_start_date, event_end_date]) if event_start_date >= start_date
  end

  def handling_end_date(date, handling_holiday)
    add_day = handling_holiday == 'after' ? 1.day : -1.day
    date += add_day while holiday?(date)

    date
  end

  def end_to_start_date(date, period)
    count = 1
    while count < period
      date -= 1.day
      next if holiday?(date)

      count += 1
    end

    date
  end

  def holiday?(date)
    @holidays[date].present? || [0, 6].include?(date.wday) # NOTE: 土日もスキップ
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_space_current_member
    @space = Space.find_by(code: params[:space_code])
    return response_not_found if @space.blank?
    return authenticate_user! if @space.private && !user_signed_in?

    @current_member = current_user.present? ? Member.where(space: @space, user: current_user)&.first : nil
    response_forbidden if @space.private && @current_member.blank?
  end

  def set_task(id = params[:id])
    @task = Task.where(id: id).eager_load(:task_cycles_active, :created_user, :last_updated_user)
                .merge(TaskCycle.order(:updated_at, :id)).first
    response_not_found if @task.blank?
  end

  def check_power
    response_forbidden unless @current_member.power_admin? || @current_member.power_writer?
  end

  def set_params_events
    errors = []

    @start_date, error = validate_date(params[:start_date])
    errors.push({ start_date: error }) if error.present?

    @end_date, error = validate_date(params[:end_date])
    errors.push({ end_date: error }) if error.present?

    if @start_date.present? && @end_date.present?
      month_count = ((@end_date.year - @start_date.year) * 12) + @end_date.month - @start_date.month + 1
      errors.push({ end_date: '3ヶ月以内で指定してください。' }) if month_count > 3
    end

    render './failure', locals: { errors: errors, alert: t('errors.messages.default') }, status: :unprocessable_entity if errors.present?
  end

  def validate_date(value)
    return nil, t('errors.messages.param.blank') if value.blank?

    result, year, month, day = */^(\d+)-(\d+)-(\d+)$/.match(value.gsub(%r{/}, '-'))
    result, year, month, day = */^(\d{4})(\d{2})(\d{2})$/.match(value) if result.blank?
    return nil, t('errors.messages.param.invalid') if result.blank? || !(0..9999).cover?(year.to_i) || !(1..12).cover?(month.to_i) || !(1..31).cover?(day.to_i)

    result = Time.new(year, month, day).to_date
    result = (result - 1.month).end_of_month if result.day != day.to_i # NOTE: 存在しない日付は丸められる為

    result
  end

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

    exist_task_cycles = target == :create ? {} : @task.task_cycles_active.index_by { |task_cycle| task_cycle_key(task_cycle) }
    @now = Time.current

    cycle_error = 0
    use_task_cycle_keys = {}
    @insert_task_cycles = []
    active_task_cycle_ids = []
    params[:task][:cycles].each.with_index(1) do |task_cycle, index|
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

    render './failure', locals: { errors: @task.errors, alert: t('errors.messages.not_saved.other') }, status: :unprocessable_entity if @task.errors.any?
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
