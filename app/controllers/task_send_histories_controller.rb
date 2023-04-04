class TaskSendHistoriesController < ApplicationController
  before_action :set_task_send_history, only: %i[show edit update destroy]

  # GET /task_send_histories or /task_send_histories.json
  def index
    @task_send_histories = TaskSendHistory.all
  end

  # GET /task_send_histories/1 or /task_send_histories/1.json
  def show; end

  # GET /task_send_histories/new
  def new
    @task_send_history = TaskSendHistory.new
  end

  # GET /task_send_histories/1/edit
  def edit; end

  # POST /task_send_histories or /task_send_histories.json
  def create
    @task_send_history = TaskSendHistory.new(task_send_history_params)

    respond_to do |format|
      if @task_send_history.save
        format.html { redirect_to @task_send_history, notice: 'Task send history was successfully created.' }
        format.json { render :show, status: :created, location: @task_send_history }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @task_send_history.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /task_send_histories/1 or /task_send_histories/1.json
  def update
    respond_to do |format|
      if @task_send_history.update(task_send_history_params)
        format.html { redirect_to @task_send_history, notice: 'Task send history was successfully updated.' }
        format.json { render :show, status: :ok, location: @task_send_history }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @task_send_history.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /task_send_histories/1 or /task_send_histories/1.json
  def destroy
    @task_send_history.destroy
    respond_to do |format|
      format.html { redirect_to task_send_histories_url, notice: 'Task send history was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_task_send_history
    @task_send_history = TaskSendHistory.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def task_send_history_params
    params.require(:task_send_history).permit(:space_id, :task_send_setting_id)
  end
end
