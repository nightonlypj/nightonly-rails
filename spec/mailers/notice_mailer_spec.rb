require 'rails_helper'

RSpec.describe NoticeMailer, type: :mailer do
  # テスト内容（共通）
  shared_examples_for 'Header' do
    it 'タイトル・送信者のメールアドレスが設定と、宛先がユーザーのメールアドレスと一致する' do
      expect(mail.subject).to eq(get_subject(mail_subject, space_name: space.name))
      expect(mail.from).to eq([Settings.mailer_from.email])
      expect(mail.to).to eq([send_setting.email_address])
    end
  end

  # 未完了タスクのお知らせ（メール）
  # テストケース
  #   target_date: 今日, 一昨日
  #   通知対象: 開始確認, 翌営業日・終了確認
  #   翌営業日開始/期限切れ/本日期限/期限内の/本日完了したタスク: ない, 2件
  describe '#incomplete_task' do
    let(:mail) do
      NoticeMailer.with(
        target_date:,
        send_history:,
        next_task_events:,
        expired_task_events:,
        end_today_task_events:,
        date_include_task_events:,
        completed_task_events:,
        force_raise:
      ).incomplete_task
    end
    let(:mail_subject) { 'mailer.notice.incomplete_task.subject' }
    let_it_be(:space) { FactoryBot.create(:space) }
    let_it_be(:send_setting) { FactoryBot.create(:send_setting, :email, space:) }
    let(:current_send_history) { SendHistory.find(send_history.id) }

    # テスト内容
    shared_examples_for 'OK' do
      let!(:start_time) { Time.current.floor }
      it_behaves_like 'Header'
      it '対象項目が含まれる。ステータスが成功、対象項目が変更される' do
        if target_date_i18n.present?
          expect(mail.html_part.body).to include(target_date_i18n)
          expect(mail.text_part.body).to include(target_date_i18n)
        end

        expect(mail.html_part.body).to include(send_history.notice_target_i18n)
        expect(mail.text_part.body).to include(send_history.notice_target_i18n)

        expect(mail.html_part.body).to include(space.name)
        expect(mail.text_part.body).to include(space.name)

        expect(mail.html_part.body).to include("\"#{space.url}\"")
        expect(mail.text_part.body).to include(space.url)

        processing_task_events = next_task_events + expired_task_events + end_today_task_events + date_include_task_events
        if processing_task_events.blank? && completed_task_events.blank?
          message = I18n.t('notifier.task_event.list.notfound')
          expect(mail.html_part.body).to include(message)
          expect(mail.text_part.body).to include(message)
        end
        (processing_task_events + completed_task_events).each_with_index do |task_event, index|
          expect(mail.html_part.body).to include(task_event.status_i18n)
          expect(mail.text_part.body).to include(task_event.status_i18n)

          if task_event.assigned_user.blank?
            key = index < processing_task_events.count ? 'notice' : 'not_notice'
            message = I18n.t("notifier.task_event.assigned.notfound.#{key}")
          else
            message = task_event.assigned_user.name
          end
          expect(mail.html_part.body).to include(message)
          expect(mail.text_part.body).to include(message)

          if task_event.task_cycle.task.priority_none?
            expect(mail.html_part.body).not_to include(task_event.task_cycle.task.priority_i18n)
            expect(mail.text_part.body).not_to include(task_event.task_cycle.task.priority_i18n)
          else
            expect(mail.html_part.body).to include(task_event.task_cycle.task.priority_i18n)
            expect(mail.text_part.body).to include(task_event.task_cycle.task.priority_i18n)
          end

          expect(mail.html_part.body).to include(task_event.task_cycle.task.title)
          expect(mail.text_part.body).to include(task_event.task_cycle.task.title)

          url = "#{space.url}?code=#{task_event.code}"
          expect(mail.html_part.body).to include("\"#{url}\"")
          expect(mail.text_part.body).to include(url)

          date = I18n.l(task_event.started_date)
          expect(mail.html_part.body).to include(date)
          expect(mail.text_part.body).to include(date)

          date = task_event.started_date == task_event.last_ended_date ? nil : I18n.l(task_event.last_ended_date)
          expect(mail.html_part.body).to include(date)
          expect(mail.text_part.body).to include(date)
        end

        expect(current_send_history.send_data).not_to be_nil
        expect(current_send_history.status.to_sym).to eq(:success)
        expect(current_send_history.completed_at).to be_between(start_time, Time.current)
      end
    end
    shared_examples_for 'NG' do
      let!(:start_time) { Time.current.floor }
      it 'ステータスが失敗、対象項目が変更される' do
        expect(mail.to).to be_nil

        expect(current_send_history.status.to_sym).to eq(:failure)
        expect(current_send_history.error_message).not_to be_nil
        expect(current_send_history.completed_at).to be_between(start_time, Time.current)
      end
    end

    # テストケース
    shared_examples_for 'target_date' do
      context '今日' do
        let(:target_date) { Time.current }
        let(:target_date_i18n) { nil }
        it_behaves_like 'OK'
      end
      context '一昨日' do
        let(:target_date) { Time.current - 2.days }
        let(:target_date_i18n) { I18n.l(target_date) }
        it_behaves_like 'OK'
      end
    end

    context '通知対象が開始確認' do
      let(:send_history) { FactoryBot.build(:send_history, :start, :email, send_setting:, target_count: 0) }
      let(:next_task_events)         { [] }
      let(:expired_task_events)      { [] }
      let(:end_today_task_events)    { [] }
      let(:date_include_task_events) { [] }
      let(:completed_task_events)    { [] }
      let(:force_raise) { nil }
      it_behaves_like 'target_date'
    end
    context '通知対象が翌営業日・終了確認' do
      let(:send_history) { FactoryBot.build(:send_history, :next, :email, send_setting:, target_count: 10) }
      include_context 'タスクイベント作成', 2, 2, 2, 2, 2
      let(:force_raise) { nil }
      it_behaves_like 'target_date'
    end
    context '例外' do
      let(:send_history) { FactoryBot.build(:send_history, :email, send_setting:, target_count: 0) }
      let(:next_task_events)         { [] }
      let(:expired_task_events)      { [] }
      let(:end_today_task_events)    { [] }
      let(:date_include_task_events) { [] }
      let(:completed_task_events)    { [] }
      let(:force_raise) { true }
      let(:target_date) { Time.current }
      let(:target_date_i18n) { nil }
      it_behaves_like 'NG'
    end
  end
end
