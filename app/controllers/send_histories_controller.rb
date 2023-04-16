class SendHistoriesController < ApplicationAuthController
  before_action :response_not_acceptable_for_not_api
  before_action :set_space_current_member_auth_private
  before_action :set_send_history, only: :show
  before_action :set_params_index, only: :index

  # GET /send_histories/:space_code(.json) 通知履歴一覧API
  def index
    # TODO
  end

  # GET /send_histories/:space_code/detail(.json) 通知履歴詳細API
  def show; end
  # TODO

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_send_history
    @send_history = SendHistory.find(params[:id])
  end

  def set_params_index
    # TODO
  end
end
