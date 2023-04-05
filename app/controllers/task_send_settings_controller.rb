class TaskSendSettingsController < ApplicationAuthController
  before_action :set_task_send_setting, only: %i[show update]

  # GET /task_send_settings/:space_code/detail(.json) タスク通知詳細API
  def show; end
  # TODO

  # POST /task_send_settings/:space_code/update(.json) タスク通知設定変更API(処理)
  def update
    # TODO
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_task_send_setting
    @task_send_setting = TaskSendSetting.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def task_send_setting_params
    params.require(:task_send_setting).permit(:space_id)
  end
end
