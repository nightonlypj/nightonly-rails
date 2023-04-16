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
    slack_domain = @slack_name.present? ? SlackDomain.find_or_initialize_by(name: @slack_name) : nil
    if slack_domain.present? && slack_domain.id.present?
      exist_send_setting = SendSetting.where(send_setting_params.merge(space: @space, slack_domain: slack_domain)).order(updated_at: :desc, id: :desc).first
    else
      exist_send_setting = nil
    end

    now = Time.current
    ActiveRecord::Base.transaction do
      if exist_send_setting.present?
        exist_send_setting.update!(last_updated_user: current_user, deleted_at: nil, updated_at: now) if exist_send_setting.deleted_at.present?
        @send_setting.update!(last_updated_user: current_user, deleted_at: now, updated_at: now) if exist_send_setting.id != @send_setting&.id
      else
        if slack_domain.present?
          slack_domain.save!
          @new_send_setting.slack_domain = slack_domain
        end
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
    if @send_setting.present? && @send_setting.slack_domain.present? && current_user.present?
      @current_slack_user = SlackUser.where(slack_domain: @send_setting.slack_domain, user: current_user).first
    else
      @current_slack_user = nil
    end
  end

  def validate_params_update
    @new_send_setting = SendSetting.new(send_setting_params.merge(space: @space, last_updated_user: current_user))
    @new_send_setting.valid?

    @slack_name = param_slack_name
    @new_send_setting.errors.add(:slack_name, t('activerecord.errors.models.send_setting.attributes.slack_name.blank')) if @new_send_setting.slack_enabled && @slack_name.blank?
    # TODO: 英字（小文字）・数字・ハイフンのみ（slack_enabledがfalseでも）
    return unless @new_send_setting.errors.any?

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

  def param_slack_name
    return if params[:send_setting].blank? || params[:send_setting][:slack].blank? || params[:send_setting][:slack][:name].blank?

    params[:send_setting][:slack][:name]
  end
end
