class SendHistoriesController < ApplicationAuthController
  include SendHistoriesConcern
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
    set_task_events(@send_history)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_send_history
    @send_history = SendHistory.where(space: @space, id: params[:id]).eager_load(send_setting: :slack_domain).first
    response_not_found if @send_history.blank?
  end
end
