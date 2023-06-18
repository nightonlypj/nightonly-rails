# Preview all emails at http://localhost:3000/rails/mailers/notice_mailer
class NoticeMailerPreview < ActionMailer::Preview
  # 未完了タスクのお知らせ（メール）
  def incomplete_task_start(notice_target = :start)
    space = FactoryBot.build_stubbed(:space)
    send_setting = FactoryBot.build_stubbed(:send_setting, :email, space: space)
    send_history = FactoryBot.build_stubbed(:send_history, notice_target, send_setting: send_setting)
    assigned_user = FactoryBot.build_stubbed(:user)

    NoticeMailer.with(
      target_date: (Time.current - (params[:target_date].present? ? params[:target_date].to_i : rand(2)).days).to_date,
      send_history: send_history,
      next_task_events: next_task_events(notice_target, space),
      expired_task_events: expired_task_events(space, assigned_user),
      end_today_task_events: end_today_task_events(space, assigned_user),
      date_include_task_events: date_include_task_events(space),
      completed_task_events: completed_task_events(space, assigned_user),
      dry_run: true
    ).incomplete_task
  end

  def incomplete_task_next
    incomplete_task_start(:next)
  end

  private

  def next_task_events(notice_target, space)
    return if notice_target != :next

    count = (params[:all] || params[:next] || rand(3)).to_i
    return [] if count == 0

    task = FactoryBot.build_stubbed(:task, :high, space: space)
    task_cycle = FactoryBot.build_stubbed(:task_cycle, task: task)
    FactoryBot.build_stubbed_list(:task_event, count, :tommorow_start, task_cycle: task_cycle)
  end

  def expired_task_events(space, assigned_user)
    count = (params[:all] || params[:expired] || rand(3)).to_i
    return [] if count == 0

    task = FactoryBot.build_stubbed(:task, :middle, space: space)
    task_cycle = FactoryBot.build_stubbed(:task_cycle, task: task)
    FactoryBot.build_stubbed_list(:task_event, count, :yesterday_end, :waiting_premise, :assigned, assigned_user: assigned_user, task_cycle: task_cycle)
  end

  def end_today_task_events(space, assigned_user)
    count = (params[:all] || params[:end_today] || rand(3)).to_i
    return [] if count == 0

    task = FactoryBot.build_stubbed(:task, :low, space: space)
    task_cycle = FactoryBot.build_stubbed(:task_cycle, task: task)
    FactoryBot.build_stubbed_list(:task_event, count, :today_end, :processing, :assigned, assigned_user: assigned_user, task_cycle: task_cycle)
  end

  def date_include_task_events(space)
    count = (params[:all] || params[:date_include] || rand(3)).to_i
    return [] if count == 0

    task = FactoryBot.build_stubbed(:task, :none, space: space)
    task_cycle = FactoryBot.build_stubbed(:task_cycle, task: task)
    FactoryBot.build_stubbed_list(:task_event, count, :update_end, task_cycle: task_cycle)
  end

  def completed_task_events(space, assigned_user)
    count = (params[:all] || params[:complete] || rand(3)).to_i
    return [] if count == 0

    task_cycle = FactoryBot.build_stubbed(:task_cycle, space: space)
    FactoryBot.build_stubbed_list(:task_event, count, :today_end, :completed, :assigned, assigned_user: assigned_user, task_cycle: task_cycle)
  end
end
