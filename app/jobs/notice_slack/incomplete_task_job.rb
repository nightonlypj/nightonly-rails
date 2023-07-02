class NoticeSlack::IncompleteTaskJob < ApplicationJob
  include ERB::Util
  include SendHistoriesConcern
  queue_as :default

  # 未完了タスクのお知らせ（Slack）
  def perform(send_history_id)
    logger.info("=== START #{self.class.name}.#{__method__}(#{send_history_id}) ===")

    @send_history = SendHistory.eager_load(:send_setting).find(send_history_id)
    set_task_events(@send_history)

    @space_url = @send_history.space.url
    @default_mention = " <#{html_escape(@send_history.send_setting.slack_mention)}>" if @send_history.send_setting.slack_mention.present?
    set_assigned_slack_users(@send_history)

    add_target_date = @send_history.target_date == Time.current.to_date ? nil : "(#{I18n.l(@send_history.target_date)})"
    message = I18n.t('notifier.task_event.message', name: "<#{@space_url}|#{html_escape(@send_history.space.name)}>")
    notice_completed = @send_history.send_setting["#{@send_history.notice_target}_notice_completed"]
    username = "#{I18n.t('app_name')}#{I18n.t('sub_title_short')}#{Settings.env_name}"
    footer_data = { footer: username, footer_icon: Settings.logo_image_url }
    send_data = {
      text: "#{add_target_date}[#{@send_history.notice_target_i18n}] #{message}",
      attachments: [
        @send_history.notice_target_next? ? attachment_task_events(:next, @next_task_event_ids) : nil,
        attachment_task_events(:expired, @expired_task_event_ids),
        attachment_task_events(:end_today, @end_today_task_event_ids),
        attachment_task_events(:date_include, @date_include_task_event_ids).merge(notice_completed ? {} : footer_data),
        notice_completed ? attachment_task_events(:completed, @completed_task_event_ids).merge(footer_data) : nil
      ].compact
    }
    @send_history.send_data = send_data.to_s

    slack_webhook_url = @send_history.send_setting.slack_webhook_url
    begin
      notifier = Slack::Notifier.new(slack_webhook_url, username:, icon_emoji: ':alarm_clock:') # NOTE: icon_urlだと背景が透過にならない為
      notifier.post(send_data)
      @send_history.status = :success
    rescue StandardError => e
      @send_history.status = :failure
      @send_history.error_message = e.message
    end
    @send_history.completed_at = Time.current
    @send_history.save!

    logger.info("=== END #{self.class.name}.#{__method__}(#{send_history_id}) ===")
  end

  private

  def attachment_task_events(type, task_event_ids)
    text = ''
    task_event_ids.each do |task_event_id|
      task_event = @task_events[task_event_id.to_i]
      next if task_event.blank?

      text += "#{task_event.slack_status_icon(type, @send_history.notice_target)} [#{task_event.status_i18n}] #{display_assigned_user(task_event)}\n" \
              "<#{@space_url}?code=#{task_event.code}|#{display_priority(task_event)}#{display_title(task_event)}> (#{display_period(task_event)})\n\n"
    end

    key = type == :completed ? "#{type}.#{@send_history.notice_target}" : type
    {
      title: I18n.t("notifier.task_event.type.#{key}.title"),
      color: I18n.t("notifier.task_event.type.#{key}.slack_color"),
      text: text.present? ? text : I18n.t('notifier.task_event.list.notfound')
    }
  end

  def display_assigned_user(task_event)
    if TaskEvent::NOT_NOTICE_STATUS.include?(task_event.status.to_sym)
      return I18n.t('notifier.task_event.assigned.notfound.not_notice') if task_event.assigned_user.blank?
    else
      return "#{I18n.t('notifier.task_event.assigned.notfound.notice')}#{@default_mention}" if task_event.assigned_user.blank?

      slack_user = @assigned_slack_users[task_event.assigned_user_id]
      return "<@#{html_escape(slack_user.memberid)}>" if slack_user.present?
    end

    html_escape(task_event.assigned_user.name)
  end

  def display_priority(task_event)
    task_event.task_cycle.task.priority_none? ? '' : "[#{task_event.task_cycle.task.priority_i18n}]"
  end

  def display_title(task_event)
    html_escape(task_event.task_cycle.task.title)
  end

  def display_period(task_event)
    I18n.l(task_event.started_date) + (task_event.started_date == task_event.last_ended_date ? '' : "〜#{I18n.l(task_event.last_ended_date)}")
  end
end
