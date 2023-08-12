class SendSettingsController < ApplicationAuthController
  before_action :response_not_acceptable_for_not_api
  before_action :authenticate_user!, only: :update
  before_action :response_api_for_user_destroy_reserved, only: :update
  before_action :set_space_current_member_auth_private
  before_action :response_api_for_space_destroy_reserved, only: :update
  before_action :check_power_admin, only: :update
  before_action :set_send_setting, only: %i[show update]
  before_action :set_current_slack_user, only: :show
  before_action :validate_params_update, only: :update

  # GET /send_settings/:space_code/detail(.json) 通知設定詳細API
  def show; end

  # POST /send_settings/:space_code/update(.json) 通知設定変更API(処理)
  def update
    if @slack_domain.present? && @slack_domain.id.present?
      exist_send_setting = SendSetting.where(send_setting_params.merge(space: @space, slack_domain: @slack_domain)).order(updated_at: :desc, id: :desc).first
    else
      exist_send_setting = nil
    end

    now = Time.current
    ActiveRecord::Base.transaction do
      if exist_send_setting.present?
        exist_send_setting.update!(last_updated_user: current_user, deleted_at: nil)
        if @send_setting.present? && @send_setting.id != exist_send_setting.id
          @send_setting.update!(last_updated_user: current_user, deleted_at: now, updated_at: now)
        end
      else
        if @slack_domain.present?
          @slack_domain.save!
          @new_send_setting.slack_domain = @slack_domain
        end
        @new_send_setting.save!
        @send_setting.update!(last_updated_user: current_user, deleted_at: now, updated_at: now) if @send_setting.present?
      end
    end

    set_send_setting
    set_current_slack_user
    render :show, locals: { notice: t('notice.send_setting.update') }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_send_setting
    @send_setting = SendSetting.active.where(space: @space).eager_load(:slack_domain, :last_updated_user).order(updated_at: :desc, id: :desc).first
  end

  def set_current_slack_user
    if @send_setting.present? && @send_setting.slack_domain.present? && current_user.present?
      @current_slack_user = SlackUser.find_by(slack_domain: @send_setting.slack_domain, user: current_user)
    else
      @current_slack_user = nil
    end
  end

  def validate_params_update
    @new_send_setting = SendSetting.new(send_setting_params.merge(space: @space, last_updated_user: current_user))
    @new_send_setting.valid?
    delete_invalid_value(:slack_enabled, :slack_webhook_url)
    delete_invalid_value(:slack_enabled, :slack_mention)
    delete_invalid_value(:email_enabled, :email_address)

    @slack_domain = SlackDomain.find_or_initialize_by(name: param_slack_name)
    if @slack_domain.invalid?
      if @new_send_setting.slack_enabled
        @slack_domain.errors.each { |error| @new_send_setting.errors.add(error.attribute == :name ? :slack_name : error.attribute, error.message) }
      end
      @slack_domain = nil # NOTE: 不正値がINSERTされないようにnilにする
    end
    return unless @new_send_setting.errors.any?

    render './failure', locals: { errors: @new_send_setting.errors, alert: t('errors.messages.not_saved.other') }, status: :unprocessable_entity
  end

  def delete_invalid_value(enabled_key, targey_key)
    return if @new_send_setting[enabled_key] || @new_send_setting.errors[targey_key].blank?

    @new_send_setting[targey_key] = nil # NOTE: バリデーションエラーにならないように空にする
    @new_send_setting.errors.delete(targey_key)
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
      start_notice_completed: start_notice[:completed],
      start_notice_required: start_notice[:required],
      next_notice_start_hour: next_notice[:start_hour],
      next_notice_completed: next_notice[:completed],
      next_notice_required: next_notice[:required]
    }
  end

  def param_slack_name
    return if params[:send_setting].blank? || params[:send_setting][:slack].blank? || params[:send_setting][:slack][:name].blank?

    params[:send_setting][:slack][:name]
  end
end
