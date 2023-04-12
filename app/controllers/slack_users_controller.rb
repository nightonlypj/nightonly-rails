class SlackUsersController < ApplicationAuthController
  before_action :set_slack_user, only: :update

  # GET /slack_users/:user_code(.json) Slackメンバー情報一覧API
  def index
    # TODO
  end

  # POST /slack_users/:user_code/update/:slack_domain_id(.json) Slackメンバー情報変更API(処理)
  def update
    # TODO
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_slack_user
    # TODO
  end

  # Only allow a list of trusted parameters through.
  def slack_user_params
    params.require(:slack_user).permit(:memberid)
  end
end
