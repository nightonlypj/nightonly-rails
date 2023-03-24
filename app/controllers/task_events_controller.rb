class TaskEventsController < ApplicationController
  before_action :set_task_event, only: %i[show edit update destroy]

  # GET /task_events or /task_events.json
  def index
    @task_events = TaskEvent.all
  end

  # GET /task_events/1 or /task_events/1.json
  def show; end

  # GET /task_events/new
  def new
    @task_event = TaskEvent.new
  end

  # GET /task_events/1/edit
  def edit; end

  # POST /task_events or /task_events.json
  def create
    @task_event = TaskEvent.new(task_event_params)

    respond_to do |format|
      if @task_event.save
        format.html { redirect_to @task_event, notice: 'Task event was successfully created.' }
        format.json { render :show, status: :created, location: @task_event }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @task_event.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /task_events/1 or /task_events/1.json
  def update
    respond_to do |format|
      if @task_event.update(task_event_params)
        format.html { redirect_to @task_event, notice: 'Task event was successfully updated.' }
        format.json { render :show, status: :ok, location: @task_event }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @task_event.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /task_events/1 or /task_events/1.json
  def destroy
    @task_event.destroy
    respond_to do |format|
      format.html { redirect_to task_events_url, notice: 'Task event was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_task_event
    @task_event = TaskEvent.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def task_event_params
    params.require(:task_event).permit(:space_id, :task_cycle_id)
  end
end
