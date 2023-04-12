class SendSettingsController < ApplicationAuthController
  before_action :response_not_acceptable_for_not_api
  before_action :set_space_current_member_auth_private
  before_action :response_api_for_user_destroy_reserved, only: :update
  before_action :check_power_admin, only: :update
  before_action :set_send_setting, only: %i[show update]
  before_action :validate_params_update, only: :update

  # GET /send_settings/:space_code/detail(.json) 通知設定詳細API
  def show; end

  # POST /send_settings/:space_code/update(.json) 通知設定変更API(処理)
  def update
    exist_send_setting = SendSetting.where(send_setting_params.merge(space: @space)).order(updated_at: :desc, id: :desc).first
    now = Time.current
    ActiveRecord::Base.transaction do
      if exist_send_setting.present?
        exist_send_setting.update!(last_updated_user: current_user, deleted_at: nil, updated_at: now) if exist_send_setting.deleted_at.present?
        @send_setting.update!(last_updated_user: current_user, deleted_at: now, updated_at: now) if exist_send_setting.id != @send_setting&.id
      else
        @new_send_setting.save!
        @send_setting.update!(last_updated_user: current_user, deleted_at: now, updated_at: now) if @send_setting.present?
      end
    end

    set_send_setting
    render :show, locals: { notice: t('notice.send_setting.update') }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_send_setting
    @send_setting = SendSetting.active.where(space: @space).eager_load(:slack_domain, :last_updated_user).order(updated_at: :desc, id: :desc).first
  end

  def validate_params_update
    @new_send_setting = SendSetting.new(send_setting_params.merge(space: @space, last_updated_user: current_user))
    return if @new_send_setting.valid?

    render './failure', locals: { errors: @new_send_setting.errors, alert: t('errors.messages.not_saved.other') }, status: :unprocessable_entity
  end

  # Only allow a list of trusted parameters through.
  def send_setting_params
    send_setting = params[:send_setting] || {}
    slack = send_setting[:slack] || {}
    email = send_setting[:email] || {}
    start_notice = send_setting[:start_notice] || {}
    next_notice  = send_setting[:next_notice] || {}
    {
      slack_enabled: slack[:enabled],
      # TODO: slack_domain: slack[:domain].present? ? slack[:domain] : nil,
      slack_webhook_url: slack[:webhook_url].present? ? slack[:webhook_url] : nil,
      slack_mention: slack[:mention].present? ? slack[:mention] : nil,
      email_enabled: email[:enabled],
      email_address: email[:address].present? ? email[:address] : nil,
      start_notice_start_hour: start_notice[:start_hour],
      start_notice_required: start_notice[:required],
      next_notice_start_hour: next_notice[:start_hour],
      next_notice_required: next_notice[:required]
    }
  end
end
