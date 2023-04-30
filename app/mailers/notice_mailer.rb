class NoticeMailer < ApplicationMailer
  # 未完了タスクのお知らせ
  def incomplete_task
    @space = params[:space]
    @target_date = params[:target_date] == Time.current.to_date ? nil : params[:target_date]
    @send_history = params[:send_history]
    @space_url = params[:space_url]
    @next_task_events = params[:next_task_events]
    @expired_task_events = params[:expired_task_events]
    @end_today_task_events = params[:end_today_task_events]
    @date_include_task_events = params[:date_include_task_events]
    @complete_task_events = params[:complete_task_events]
    begin
      @send_history.send_data = mail(
        from: "\"#{Settings.mailer_from.name.gsub(/%{app_name}/, t('app_name'))}\" <#{Settings.mailer_from.email}>",
        to: @send_history.send_setting.email_address,
        subject: t('mailer.notice.incomplete_task.subject', app_name: I18n.t('app_name'), env_name: Settings.env_name || '', space_name: @space.name)
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
