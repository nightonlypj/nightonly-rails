class TaskEventsController < ApplicationAuthController
  include TasksConcern
  include TaskCyclesConcern

  before_action :response_not_acceptable_for_not_api
  before_action :authenticate_user!, only: :update
  before_action :response_api_for_user_destroy_reserved, only: :update
  before_action :set_space_current_member_auth_private
  before_action :response_api_for_space_destroy_reserved, only: :update
  before_action :check_power_writer, only: :update
  before_action :set_task_event, only: %i[show update]
  before_action :set_params_index, only: :index
  before_action :validate_params_update, only: :update

  # GET /task_events/:space_code(.json) タスクイベント一覧API
  def index
    @events = []
    @months = nil
    @next_events = {}

    @tasks = {}
    @task_events = TaskEvent.where(space: @space, started_date: @start_date..@end_date)
      .eager_load(task_cycle: [task: %i[created_user last_updated_user]]).merge(Task.order(:priority)).order(:id)
    @task_events.each do |task_event|
      task_cycle = task_event.task_cycle
      @tasks[task_cycle.task_id] = task_cycle.task if @tasks[task_cycle.task_id].blank?
    end

    next_start_date = [@start_date, Time.zone.today].max
    return if next_start_date > @end_date

    set_exist_task_events
    logger.debug "@exist_task_events: #{@exist_task_events}"

    set_holidays(@start_date - 2.months, @end_date) # NOTE: 期間が20営業日でも1ヶ月を超える場合がある為
    task_cycles = TaskCycle.active.where(space: @space).by_month(cycle_months(next_start_date, @end_date) + [nil])
      .eager_load(task: %i[created_user last_updated_user])
      .by_task_period(next_start_date, @end_date).merge(Task.order(:priority)).order(:order, :updated_at, :id)
    task_cycles.each do |task_cycle|
      result = cycle_set_next_events(task_cycle, task_cycle.task, next_start_date, @end_date)
      @tasks[task_cycle.task_id] = task_cycle.task if result && @tasks[task_cycle.task_id].blank?
    end
  end

  # GET /task_events/:space_code/detail/:code(.json) タスクイベント詳細API
  def show
    set_task(@task_event.task_cycle.task_id)
    set_task_assigne_users if @task.present?
  end

  # POST /task_events/:space_code/update/:code(.json) タスクイベント変更API(処理)
  def update
    if @task_event.new_assigned_user.blank?
      @task_event.assigned_user = nil
      @task_event.assigned_at = nil
    elsif @task_event.assigned_user != @task_event.new_assigned_user
      @task_event.assigned_user = @task_event.new_assigned_user
      @task_event.assigned_at = Time.current
    end

    before_not_notice_status = TaskEvent::NOT_NOTICE_STATUS.include?(@task_event.status_was&.to_sym)
    after_not_notice_status = TaskEvent::NOT_NOTICE_STATUS.include?(@task_event.status.to_sym)
    @task_event.last_completed_at = Time.current if !before_not_notice_status && after_not_notice_status
    @task_event.last_completed_at = nil if before_not_notice_status && !after_not_notice_status
    @task_event.save!

    render locals: { notice: t('notice.task_event.update') }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_task_event
    @task_event = TaskEvent.where(space: @space, code: params[:code]).eager_load(:task_cycle, :assigned_user, :last_updated_user).first
    response_not_found if @task_event.blank?
  end

  def set_params_index
    errors = {}

    @start_date, error = validate_date(params[:start_date])
    errors[:start_date] = [error] if error.present?

    @end_date, error = validate_date(params[:end_date])
    errors[:end_date] = [error] if error.present?

    if @start_date.present? && @end_date.present?
      if @start_date > @end_date
        errors[:end_date] = [t('errors.messages.task_events.end_date.after')]
      else
        month_count = ((@end_date.year - @start_date.year) * 12) + @end_date.month - @start_date.month + 1
        if month_count > Settings.task_events_max_month_count
          errors[:end_date] = [t('errors.messages.task_events.max_month_count', count: Settings.task_events_max_month_count)]
        end
      end
    end

    render '/failure', locals: { errors:, alert: t('errors.messages.default') }, status: :unprocessable_content if errors.present?
  end

  def validate_date(value)
    return nil, t('errors.messages.param.blank') if value.blank?

    result, year, month, day = */^(\d+)-(\d+)-(\d+)$/.match(value.tr('/', '-'))
    result, year, month, day = */^(\d{4})(\d{2})(\d{2})$/.match(value) if result.blank?
    return nil, t('errors.messages.param.invalid') if result.blank? || !(0..9999).cover?(year.to_i) || !(1..12).cover?(month.to_i) || !(1..31).cover?(day.to_i)

    result = Time.zone.local(year, month, day).to_date
    result = (result - 1.month).end_of_month if result.day != day.to_i # NOTE: 存在しない日付は丸められる為

    result
  end

  def validate_params_update
    @detail = params[:detail].to_s == 'true'
    @task_event.assign_attributes(task_event_params.merge(last_updated_user: current_user))
    return if @task_event.valid?

    render '/failure', locals: { errors: @task_event.errors, alert: t('errors.messages.not_saved.other') }, status: :unprocessable_content
  end

  # Only allow a list of trusted parameters through.
  def task_event_params
    params[:task_event] = TaskEvent.new.attributes if params[:task_event].blank? # NOTE: 変更なしで成功する為
    params[:task_event][:status] = nil if TaskEvent.statuses[params[:task_event][:status]].blank? # NOTE: ArgumentError対策
    assigned_user_code = params[:task_event][:assigned_user].present? ? params[:task_event][:assigned_user][:code] : nil

    params.expect(task_event: %i[last_ended_date status memo]).merge(assigned_user_code:)
  end
end
