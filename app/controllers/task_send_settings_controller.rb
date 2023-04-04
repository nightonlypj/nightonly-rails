class TaskSendSettingsController < ApplicationController
  before_action :set_task_send_setting, only: %i[show edit update destroy]

  # GET /task_send_settings or /task_send_settings.json
  def index
    @task_send_settings = TaskSendSetting.all
  end

  # GET /task_send_settings/1 or /task_send_settings/1.json
  def show; end

  # GET /task_send_settings/new
  def new
    @task_send_setting = TaskSendSetting.new
  end

  # GET /task_send_settings/1/edit
  def edit; end

  # POST /task_send_settings or /task_send_settings.json
  def create
    @task_send_setting = TaskSendSetting.new(task_send_setting_params)

    respond_to do |format|
      if @task_send_setting.save
        format.html { redirect_to @task_send_setting, notice: 'Task send setting was successfully created.' }
        format.json { render :show, status: :created, location: @task_send_setting }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @task_send_setting.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /task_send_settings/1 or /task_send_settings/1.json
  def update
    respond_to do |format|
      if @task_send_setting.update(task_send_setting_params)
        format.html { redirect_to @task_send_setting, notice: 'Task send setting was successfully updated.' }
        format.json { render :show, status: :ok, location: @task_send_setting }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @task_send_setting.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /task_send_settings/1 or /task_send_settings/1.json
  def destroy
    @task_send_setting.destroy
    respond_to do |format|
      format.html { redirect_to task_send_settings_url, notice: 'Task send setting was successfully destroyed.' }
      format.json { head :no_content }
    end
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
