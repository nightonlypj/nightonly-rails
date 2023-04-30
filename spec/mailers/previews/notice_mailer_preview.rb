# Preview all emails at http://localhost:3000/rails/mailers/notice_mailer
class NoticeMailerPreview < ActionMailer::Preview
  # 未完了タスクのお知らせ
  def incomplete_task_start(notice_target = :start)
    space = FactoryBot.build_stubbed(:space)
    send_setting = FactoryBot.build_stubbed(:send_setting, :email, space: space)
    send_history = FactoryBot.build_stubbed(:send_history, notice_target, space: space, send_setting: send_setting)
    task_cycle = FactoryBot.build_stubbed(:task_cycle, space: space)
    next_task_events = notice_target == :next ? FactoryBot.build_stubbed_list(:task_event, rand(3), space: space, task_cycle: task_cycle) : nil
    expired_task_events = FactoryBot.build_stubbed_list(:task_event, rand(3), space: space, task_cycle: task_cycle)
    end_today_task_events = FactoryBot.build_stubbed_list(:task_event, rand(3), space: space, task_cycle: task_cycle)
    date_include_task_events = FactoryBot.build_stubbed_list(:task_event, rand(3), :yesterday, :assigned, space: space, task_cycle: task_cycle)
    complete_task_events = [
      FactoryBot.build_stubbed(:task_event, :completed, space: space, task_cycle: task_cycle),
      FactoryBot.build_stubbed(:task_event, :completed, :yesterday, :assigned, space: space, task_cycle: task_cycle)
    ]
    NoticeMailer.with(
      space: space,
      target_date: [Time.current, Time.current.yesterday][rand(2)].to_date,
      send_history: send_history,
      space_url: "#{Settings.front_url}/-/#{space.code}",
      next_task_events: next_task_events,
      expired_task_events: expired_task_events,
      end_today_task_events: end_today_task_events,
      date_include_task_events: date_include_task_events,
      complete_task_events: complete_task_events,
      dry_run: true
    ).incomplete_task
  end

  def incomplete_task_next
    incomplete_task_start(:next)
  end
end
