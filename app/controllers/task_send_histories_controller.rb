class TaskSendHistoriesController < ApplicationAuthController
  before_action :response_not_acceptable_for_not_api
  before_action :set_space_current_member_auth_private
  before_action :set_task_send_history, only: :show
  before_action :set_params_index, only: :index

  # GET /task_send_histories/:space_code(.json) タスク通知履歴一覧API
  def index
    # TODO
  end

  # GET /task_send_histories/:space_code/detail(.json) タスク通知履歴詳細API
  def show; end
  # TODO

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_task_send_history
    @task_send_history = TaskSendHistory.find(params[:id])
  end

  def set_params_index
    # TODO
  end
end
