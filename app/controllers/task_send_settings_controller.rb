class TaskSendSettingsController < ApplicationAuthController
  before_action :response_not_acceptable_for_not_api
  before_action :set_space_current_member_auth_private
  before_action :response_api_for_user_destroy_reserved, only: :update
  before_action :check_power_admin, only: :update
  before_action :set_task_send_setting, only: %i[show update]
  before_action :validate_params_update, only: :update

  # GET /task_send_settings/:space_code/detail(.json) タスク通知設定詳細API
  def show; end

  # POST /task_send_settings/:space_code/update(.json) タスク通知設定変更API(処理)
  def update
    exist_task_send_setting = TaskSendSetting.where(task_send_setting_params.merge(space: @space)).order(updated_at: :desc, id: :desc).first
    now = Time.current
    ActiveRecord::Base.transaction do
      if exist_task_send_setting.present?
        exist_task_send_setting.update!(last_updated_user: current_user, deleted_at: nil, updated_at: now) if exist_task_send_setting.deleted_at.present?
        @task_send_setting.update!(last_updated_user: current_user, deleted_at: now, updated_at: now) if exist_task_send_setting.id != @task_send_setting&.id
      else
        @new_task_send_setting.save!
        @task_send_setting.update!(last_updated_user: current_user, deleted_at: now, updated_at: now) if @task_send_setting.present?
      end
    end

    set_task_send_setting
    render :show, locals: { notice: t('notice.task_send_setting.update') }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_task_send_setting
    @task_send_setting = TaskSendSetting.active.where(space: @space).eager_load(:last_updated_user).order(updated_at: :desc, id: :desc).first
  end

  def validate_params_update
    @new_task_send_setting = TaskSendSetting.new(task_send_setting_params.merge(space: @space, last_updated_user: current_user))
    return if @new_task_send_setting.valid?

    render './failure', locals: { errors: @new_task_send_setting.errors, alert: t('errors.messages.not_saved.other') }, status: :unprocessable_entity
  end

  # Only allow a list of trusted parameters through.
  def task_send_setting_params
    task_send_setting = params[:task_send_setting] || {}
    slack = task_send_setting[:slack] || {}
    email = task_send_setting[:email] || {}
    today_notice = task_send_setting[:today_notice] || {}
    next_notice  = task_send_setting[:next_notice] || {}
    {
      slack_enabled: slack[:enabled],
      slack_webhook_url: slack[:webhook_url].present? ? slack[:webhook_url] : nil,
      slack_mention: slack[:mention].present? ? slack[:mention] : nil,
      email_enabled: email[:enabled],
      email_address: email[:address].present? ? email[:address] : nil,
      today_notice_start_hour: today_notice[:start_hour],
      today_notice_required: today_notice[:required],
      next_notice_start_hour: next_notice[:start_hour],
      next_notice_required: next_notice[:required]
    }
  end
end
