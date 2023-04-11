class SlackUsersController < ApplicationController
  before_action :set_slack_user, only: %i[show edit update destroy]

  # GET /slack_users or /slack_users.json
  def index
    @slack_users = SlackUser.all
  end

  # GET /slack_users/1 or /slack_users/1.json
  def show; end

  # GET /slack_users/new
  def new
    @slack_user = SlackUser.new
  end

  # GET /slack_users/1/edit
  def edit; end

  # POST /slack_users or /slack_users.json
  def create
    @slack_user = SlackUser.new(slack_user_params)

    respond_to do |format|
      if @slack_user.save
        format.html { redirect_to @slack_user, notice: 'Slack user was successfully created.' }
        format.json { render :show, status: :created, location: @slack_user }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @slack_user.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /slack_users/1 or /slack_users/1.json
  def update
    respond_to do |format|
      if @slack_user.update(slack_user_params)
        format.html { redirect_to @slack_user, notice: 'Slack user was successfully updated.' }
        format.json { render :show, status: :ok, location: @slack_user }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @slack_user.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /slack_users/1 or /slack_users/1.json
  def destroy
    @slack_user.destroy
    respond_to do |format|
      format.html { redirect_to slack_users_url, notice: 'Slack user was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_slack_user
    @slack_user = SlackUser.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def slack_user_params
    params.require(:slack_user).permit(:slack_domain_id, :user_id, :memberid, :string)
  end
end
