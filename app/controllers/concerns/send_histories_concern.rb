module SendHistoriesConcern
  extend ActiveSupport::Concern

  private

  def set_task_events(send_history)
    @next_task_event_ids = to_array(send_history.next_task_event_ids)
    @expired_task_event_ids = to_array(send_history.expired_task_event_ids)
    @end_today_task_event_ids = to_array(send_history.end_today_task_event_ids)
    @date_include_task_event_ids = to_array(send_history.date_include_task_event_ids)
    @completed_task_event_ids = to_array(send_history.completed_task_event_ids)

    task_event_ids = @next_task_event_ids + @expired_task_event_ids + @end_today_task_event_ids + @date_include_task_event_ids + @completed_task_event_ids
    @task_events = TaskEvent.where(space: send_history.space, id: task_event_ids).eager_load({ task_cycle: :task }, :assigned_user).index_by(&:id)
  end

  def set_assigned_slack_users(send_history)
    assigned_user_ids = {}
    @task_events.each_value do |task_event|
      assigned_user_ids[task_event.assigned_user_id] = true if task_event.assigned_user.present?
    end
    if assigned_user_ids.blank?
      @assigned_slack_users = {}
      return
    end

    @assigned_slack_users = SlackUser.where(slack_domain_id: send_history.send_setting.slack_domain_id, user: assigned_user_ids.keys).index_by(&:user_id)
  end

  def to_array(value)
    value.present? ? value.split(',') : []
  end
end
