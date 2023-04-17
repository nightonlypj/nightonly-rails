class SendHistoriesController < ApplicationAuthController
  before_action :response_not_acceptable_for_not_api
  before_action :set_space_current_member_auth_private
  before_action :set_send_history, only: :show

  # GET /send_histories/:space_code(.json) 通知履歴一覧API
  def index
    @send_histories = SendHistory.where(space: @space).eager_load(:send_setting).order(target_date: :desc, completed_at: :desc, id: :desc)
                                 .page(params[:page]).per(Settings.default_send_histories_limit)
  end

  # GET /send_histories/:space_code/detail/:id(.json) 通知履歴詳細API
  def show
    @next_task_event_ids = to_array(@send_history.next_task_event_ids)
    @expired_task_event_ids = to_array(@send_history.expired_task_event_ids)
    @end_today_task_event_ids = to_array(@send_history.end_today_task_event_ids)
    @date_include_task_event_ids = to_array(@send_history.date_include_task_event_ids)

    task_event_ids = @next_task_event_ids + @expired_task_event_ids + @end_today_task_event_ids + @date_include_task_event_ids
    @task_events = TaskEvent.where(space: @space, id: task_event_ids).eager_load(task_cycle: :task).index_by(&:id)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_send_history
    @send_history = SendHistory.where(space: @space, id: params[:id]).eager_load(send_setting: :slack_domain).first
    response_not_found if @send_history.blank?
  end

  def to_array(value)
    value.present? ? value.split(',') : []
  end
end
