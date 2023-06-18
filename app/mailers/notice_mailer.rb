class NoticeMailer < ApplicationMailer
  # 未完了タスクのお知らせ（メール）
  def incomplete_task
    @target_date = params[:target_date] == Time.current.to_date ? nil : params[:target_date]
    @send_history = params[:send_history]
    @next_task_events = params[:next_task_events]
    @expired_task_events = params[:expired_task_events]
    @end_today_task_events = params[:end_today_task_events]
    @date_include_task_events = params[:date_include_task_events]
    @completed_task_events = params[:completed_task_events]

    @space_name = @send_history.space.name
    @space_url = @send_history.space.url
    begin
      raise if Rails.env.test? && params[:force_raise]

      @send_history.send_data = mail(
        from: "\"#{Settings.mailer_from.name.gsub(/%{app_name}/, t('app_name'))}\" <#{Settings.mailer_from.email}>",
        to: @send_history.send_setting.email_address,
        subject: t('mailer.notice.incomplete_task.subject', app_name: t('app_name'), env_name: Settings.env_name || '', space_name: @space_name)
      )
      @send_history.status = :success
    rescue StandardError => e
      @send_history.status = :failure
      @send_history.error_message = e.message
    end
    @send_history.completed_at = Time.current
    @send_history.save! unless params[:dry_run]
  end
end
