class TasksController < ApplicationAuthController
  include TasksConcern
  before_action :response_not_acceptable_for_not_api
  before_action :set_space_current_member
  # before_action :response_api_for_user_destroy_reserved, only: %i[create update destroy]
  # before_action :check_power, only: %i[create update destroy]
  # before_action :set_task, only: :show
  before_action :set_params_index, only: :index
  before_action :set_params_events, only: :events
  # before_action :validate_params_create, only: :create
  # before_action :validate_params_update, only: :update

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
    task_cycles = TaskCycle.where(space: @space).by_month(cycle_months + [nil])
                           .eager_load(:task).by_task_period(@next_start_date, @end_date).order('tasks.priority', :id)
    task_cycles.each do |task_cycle|
      case task_cycle.cycle.to_sym
      when :weekly
        weekly_set_next_events(task_cycle)
      when :monthly
        monthly_set_next_events(task_cycle)
      when :yearly
        yearly_set_next_events(task_cycle)
      else
        raise "task_cycle.cycle not found.(#{task_cycle.cycle})"
      end

      if before_count != @next_events.count
        @tasks[task_cycle.task_id] = task_cycle.task if @tasks[task_cycle.task_id].blank?
        before_count = @next_events.count
      end
    end
  end

  # GET /tasks/:space_code/detail/:id(.json) タスク詳細API
  def show; end
  # TODO

  # POST /tasks/:space_code/create(.json) タスク登録API(処理)
  def create
    # TODO
  end

  # POST /tasks/:space_code/update/:id(.json) タスク設定変更API(処理)
  def update
    # TODO
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

  def weekly_set_next_events(task_cycle)
    date = @next_start_date + ((task_cycle.wday_before_type_cast - @next_start_date.wday) % 7).days
    while date <= @end_date # NOTE: 終了日が期間内のもの。開始日のみ期間内のものは含まれない。期間(task_cycles.period)が1ヶ月以下の前提
      set_next_events(date, task_cycle)
      date += 1.week
    end
  end

  def monthly_set_next_events(task_cycle)
    month = @next_start_date.beginning_of_month
    while month <= @end_date # NOTE: 終了日が期間内のもの。開始日のみ期間内のものは含まれない。期間(task_cycles.period)が1ヶ月以下の前提
      day_set_next_events(month, task_cycle) if task_cycle.day.present?
      business_day_set_next_events(month, task_cycle) if task_cycle.business_day.present?
      week_set_next_events(month, task_cycle) if task_cycle.week.present?
      month += 1.month
    end
  end

  def yearly_set_next_events(task_cycle)
    month = @next_start_date.beginning_of_month
    while month <= @end_date # NOTE: 終了日が期間内のもの。開始日のみ期間内のものは含まれない。期間(task_cycles.period)が1ヶ月以下の前提
      if month.month == task_cycle.month
        day_set_next_events(month, task_cycle) if task_cycle.day.present?
        business_day_set_next_events(month, task_cycle) if task_cycle.business_day.present?
        week_set_next_events(month, task_cycle) if task_cycle.week.present?
        break if month.year >= @end_date.year
      end
      month += 1.month
    end
  end

  def day_set_next_events(month, task_cycle)
    date = month + (task_cycle.day - 1).days
    date = (date - 1.month).end_of_month if date.day != task_cycle.day # NOTE: 存在しない日付は丸められる為
    set_next_events(date, task_cycle)
  end

  def business_day_set_next_events(month, task_cycle)
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
    set_next_events(date, task_cycle)
  end

  def week_set_next_events(month, task_cycle)
    date = month + ((task_cycle.wday_before_type_cast - month.wday) % 7).days + ((task_cycle.week_before_type_cast - 1) * 7).days
    date -= 7.days while date.month > month.month
    set_next_events(date, task_cycle)
  end

  def set_next_events(date, task_cycle)
    end_date = handling_end_date(date, task_cycle.handling_holiday)
    return if end_date < @next_start_date

    start_date = end_to_start_date(end_date, task_cycle.period)
    @next_events.push([task_cycle, start_date, end_date]) if start_date >= @next_start_date
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

  def set_task
    # TODO
  end

  # Only allow a list of trusted parameters through.
  def task_params
    # TODO
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
end
