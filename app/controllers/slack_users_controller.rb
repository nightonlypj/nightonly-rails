class SlackUsersController < ApplicationAuthController
  before_action :response_not_acceptable_for_not_api
  before_action :authenticate_user!
  before_action :response_api_for_user_destroy_reserved, only: :update
  before_action :set_slack_users, only: :index
  before_action :validate_params_update, only: :update

  # GET /slack_users(.json) Slackユーザー情報一覧API
  def index; end

  # POST /slack_users/update(.json) Slackユーザー情報変更API(処理)
  def update
    slack_domains = SlackDomain.where(name: @memberids.keys).index_by(&:name)
    ActiveRecord::Base.transaction do
      @memberids.each do |name, memberid| # TODO: バルク
        slack_user = SlackUser.find_or_initialize_by(slack_domain: slack_domains[name], user: current_user)
        slack_user.memberid = memberid
        slack_user.save!
      end
    end

    set_slack_users
    render :index, locals: { notice: t('notice.slack_user.update') }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_slack_users
    members = current_user.members.joins({ space: :send_setting_active })
                          .merge(SendSetting.order(updated_at: :desc, id: :desc)).order(:id)
    slack_domain_ids = members.map { |member| member.space.send_setting_active.first.slack_domain_id }.uniq
    @slack_domains = SlackDomain.where(id: slack_domain_ids).order(:name)
    @slack_users = SlackUser.where(slack_domain_id: slack_domain_ids, user: current_user).index_by(&:slack_domain_id)
  end

  def validate_params_update
    errors = {}
    @memberids = {}
    if params[:slack_users].blank?
      errors[:memberid1] = [t('activerecord.errors.models.slack_user.attributes.memberid.blank')]
    else
      members = current_user.members.joins({ space: { send_setting_active: :slack_domain } })
                            .merge(SendSetting.order(updated_at: :desc, id: :desc)).order(:id)
      domain_names = members.map { |member| member.space.send_setting_active.first.slack_domain.name }.uniq

      params[:slack_users].each.with_index(1) do |slack_user, index|
        next errors["name#{index}".to_sym] = [t('errors.messages.param.blank')] if slack_user[:name].blank?
        next errors["name#{index}".to_sym] = [t('errors.messages.param.not_exist')] unless domain_names.include?(slack_user[:name])

        if slack_user[:memberid].length > Settings.slack_user_memberid_maximum
          key = 'activerecord.errors.models.slack_user.attributes.memberid.too_long'
          next errors["memberid#{index}".to_sym] = [t(key, count: Settings.slack_user_memberid_maximum)]
        end
        # TODO: 英字（大文字）・数字のみ

        @memberids[slack_user[:name]] = slack_user[:memberid]
      end
    end

    render './failure', locals: { errors: errors, alert: t('errors.messages.not_saved.other') }, status: :unprocessable_entity if errors.present?
  end

  # Only allow a list of trusted parameters through.
  def slack_user_params
    params.require(:slack_user).permit(:memberid)
  end
end
