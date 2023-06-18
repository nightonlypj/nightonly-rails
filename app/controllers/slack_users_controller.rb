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
    insert_datas = []
    update_datas = []
    slack_domains = SlackDomain.where(name: @memberids.keys).index_by(&:name)
    slack_users = SlackUser.where(slack_domain: slack_domains.values, user: current_user).index_by { |slack_user| slack_user.slack_domain.name }
    now = Time.current
    @memberids.each do |name, memberid|
      slack_user = slack_users[name]
      if slack_user.blank?
        insert_datas.push(slack_domain_id: slack_domains[name].id, user_id: current_user.id, memberid: memberid, created_at: now, updated_at: now)
      elsif memberid != slack_user.memberid
        update_datas.push(slack_user.attributes.merge(memberid: memberid, updated_at: now))
      end
    end
    SlackUser.insert_all!(insert_datas) if insert_datas.present?
    SlackUser.upsert_all(update_datas) if update_datas.present?

    set_slack_users
    render :index, locals: { notice: t('notice.slack_user.update') }
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_slack_users
    slack_domain_ids = current_members.map { |member| member.space.send_setting_active.first.slack_domain_id }.uniq
    @slack_domains = SlackDomain.where(id: slack_domain_ids).order(:name)
    @slack_users = SlackUser.where(slack_domain_id: slack_domain_ids, user: current_user).index_by(&:slack_domain_id)
  end

  MEMBERID_KEY = 'activerecord.errors.models.slack_user.attributes.memberid'.freeze
  def validate_params_update
    errors = {}
    @memberids = {}
    if params[:slack_users].blank? || !params[:slack_users].instance_of?(Array)
      errors[:name1] = [t('errors.messages.param.blank')]
      errors[:memberid1] = [t("#{MEMBERID_KEY}.blank")]
    else
      domain_names = current_members.map { |member| member.space.send_setting_active.first.slack_domain.name }.uniq

      params[:slack_users].each.with_index(1) do |slack_user, index|
        key = "name#{index}".to_sym
        next errors[key] = [t('errors.messages.param.blank')] if slack_user[:name].blank?
        next errors[key] = [t('errors.messages.param.not_exist')] unless domain_names.include?(slack_user[:name])

        if slack_user[:memberid].present?
          key = "memberid#{index}".to_sym
          minimum = Settings.slack_user_memberid_minimum
          next errors[key] = [t("#{MEMBERID_KEY}.too_short", count: minimum)] if slack_user[:memberid].length < minimum

          maximum = Settings.slack_user_memberid_maximum
          next errors[key] = [t("#{MEMBERID_KEY}.too_long", count: maximum)] if slack_user[:memberid].length > maximum
          next errors[key] = [t("#{MEMBERID_KEY}.invalid")] if (slack_user[:memberid] =~ SlackUser::MEMBERID_FORMAT).nil?
        end

        @memberids[slack_user[:name]] = slack_user[:memberid]
      end
    end

    render './failure', locals: { errors: errors, alert: t('errors.messages.not_saved.other') }, status: :unprocessable_entity if errors.present?
  end

  def current_members
    current_user.members.where(power: %i[admin writer]).joins({ space: { send_setting_active: :slack_domain } })
                .merge(SendSetting.order(updated_at: :desc, id: :desc)).order(:id)
  end
end
