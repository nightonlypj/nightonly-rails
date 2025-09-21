require 'rails_helper'

RSpec.describe NoticeSlack::IncompleteTaskJob, type: :job do
  include ERB::Util

  # 未完了タスクのお知らせ（Slack）
  # 前提条件
  # テストパターン
  #   レスポンス: 成功, 失敗
  #   通知設定
  #     (Slack)メンション: ある, ない
  #     (開始確認/翌営業日・終了確認)完了通知: する, しない
  #   通知履歴
  #     対象日: 当日, 前日
  #     通知対象: 開始確認, 翌営業日・終了確認
  #     タスクイベント: ある, ない
  describe '.perform' do
    subject { job.perform(send_history.id) }
    let(:job) { described_class.new }

    let_it_be(:user) { FactoryBot.create(:user) }
    let_it_be(:slack_domain) { FactoryBot.create(:slack_domain) }
    let_it_be(:slack_user) { FactoryBot.create(:slack_user, slack_domain:, user:) }

    let_it_be(:space) { FactoryBot.create(:space, created_user: user) }
    let_it_be(:tasks) { Task.priorities.keys.map { |priority| FactoryBot.create(:task, space:, priority:, created_user: user) } }
    let_it_be(:next_task_events) do
      task_cycle = FactoryBot.create(:task_cycle, task: tasks[0])
      [FactoryBot.create(:task_event, :tommorow_start, task_cycle:)]
    end
    let_it_be(:expired_task_events) do
      task_cycle = FactoryBot.create(:task_cycle, task: tasks[0])
      [FactoryBot.create(:task_event, :yesterday_end, :waiting_premise, task_cycle:)]
    end
    let_it_be(:end_today_task_events) do
      task_cycle = FactoryBot.create(:task_cycle, task: tasks[1])
      [FactoryBot.create(:task_event, :today_end, :processing, :assigned, task_cycle:)]
    end
    let_it_be(:date_include_task_events) do
      task_cycles = Array.new(2) { |index| FactoryBot.create(:task_cycle, task: tasks[index + 2]) }
      [
        FactoryBot.create(:task_event, :tommorow_end, :assigned, task_cycle: task_cycles[0], assigned_user: user),
        FactoryBot.create(:task_event, :today_end, :update_end, task_cycle: task_cycles[1])
      ]
    end
    let_it_be(:completed_task_events) do
      task_cycles = Array.new(2) { |index| FactoryBot.create(:task_cycle, task: tasks[index + 2]) }
      [
        FactoryBot.create(:task_event, :completed, :assigned, task_cycle: task_cycles[0], assigned_user: user),
        FactoryBot.create(:task_event, :completed, task_cycle: task_cycles[1])
      ]
    end

    # テスト内容
    let(:current_send_history) { SendHistory.find(send_history.id) }
    shared_examples_for 'OK' do |status|
      let!(:start_time) { Time.current.floor }
      it "ステータスが#{status}、対象項目が変更される" do
        subject
        expect(current_send_history.status.to_sym).to eq(status)
        expect(current_send_history.completed_at).to be_between(start_time, Time.current)
        expect(current_send_history.error_message).to status == :failure ? be_present : be_nil
        expect(current_send_history.send_data).not_to be_nil
        next if status != :success

        send_data = eval(current_send_history.send_data)
        message = I18n.t('notifier.task_event.message', name: "<#{send_history.space.url}|#{html_escape(send_history.space.name)}>")
        expect(send_data[:text]).to eq("#{add_target_date}[#{send_history.notice_target_i18n}] #{message}")

        except_attachments = []
        except_attachments.push({ type: :next, task_events: send_history.next_task_event_ids.present? ? next_task_events : [] }) if notice_target == :next
        except_attachments.push({ type: :expired, task_events: send_history.expired_task_event_ids.present? ? expired_task_events : [] })
        except_attachments.push({ type: :end_today, task_events: send_history.end_today_task_event_ids.present? ? end_today_task_events : [] })
        except_attachments.push({ type: :date_include, task_events: send_history.date_include_task_event_ids.present? ? date_include_task_events : [] })
        if notice_completed
          except_attachments.push({ type: :completed, task_events: send_history.completed_task_event_ids.present? ? completed_task_events : [] })
        end

        expect(send_data[:attachments].count).to eq(except_attachments.count)
        send_data[:attachments].each_with_index do |attachment, index|
          type = except_attachments[index][:type]
          key = type == :completed ? "#{type}.#{notice_target}" : type
          expect(attachment[:title]).to eq(I18n.t("notifier.task_event.type.#{key}.title"))
          expect(attachment[:color]).to eq(I18n.t("notifier.task_event.type.#{key}.slack_color"))

          task_events = except_attachments[index][:task_events]
          expect(attachment[:text]).to eq(I18n.t('notifier.task_event.list.notfound')) if task_events.blank?
          task_events.each do |task_event|
            expect(attachment[:text]).to include(task_event.slack_status_icon(type, notice_target))
            expect(attachment[:text]).to include("[#{task_event.status_i18n}]")

            if type == :completed
              if task_event.assigned_user.blank?
                expect(attachment[:text]).to include(I18n.t('notifier.task_event.assigned.notfound.not_notice'))
              else
                expect(attachment[:text]).to include(html_escape(task_event.assigned_user.name))
              end
            elsif task_event.assigned_user.blank?
              default_mention = slack_mention.present? ? " <#{slack_mention}>" : nil
              expect(attachment[:text]).to include("#{I18n.t('notifier.task_event.assigned.notfound.notice')}#{default_mention}")
            elsif task_event.assigned_user == user
              expect(attachment[:text]).to include("<@#{html_escape(slack_user.memberid)}>")
            else
              expect(attachment[:text]).to include(html_escape(task_event.assigned_user.name))
            end

            expect(attachment[:text]).to include("<#{space.url}?code=#{task_event.code}|")
            if task_event.task_cycle.task.priority_none?
              expect(attachment[:text]).not_to include("[#{task_event.task_cycle.task.priority_i18n}]")
            else
              expect(attachment[:text]).to include("[#{task_event.task_cycle.task.priority_i18n}]")
            end
            expect(attachment[:text]).to include(html_escape(task_event.task_cycle.task.title))
            if task_event.started_date == task_event.last_ended_date
              expect(attachment[:text]).to include(I18n.l(task_event.started_date))
            else
              expect(attachment[:text]).to include("#{I18n.l(task_event.started_date)}〜#{I18n.l(task_event.last_ended_date)}")
            end
          end

          if index + 1 == except_attachments.count
            expect(attachment[:footer]).to eq("#{I18n.t('app_name')}#{I18n.t('sub_title_short')}#{Settings.env_name}")
            expect(attachment[:footer_icon]).to eq(Settings.logo_image_url)
          else
            expect(attachment[:footer]).to be_nil
          end
        end
      end
    end

    # テストケース
    shared_examples_for '通知履歴のタスクイベント' do
      context 'ある' do
        let_it_be(:send_history) do
          FactoryBot.create(:send_history, send_setting:, target_date:, notice_target:,
                                           next_task_event_ids: notice_target == :next ? next_task_events.pluck(:id).join(',') : nil,
                                           expired_task_event_ids: expired_task_events.pluck(:id).join(','),
                                           end_today_task_event_ids: end_today_task_events.pluck(:id).join(','),
                                           date_include_task_event_ids: date_include_task_events.pluck(:id).join(','),
                                           completed_task_event_ids: notice_completed ? completed_task_events.pluck(:id).join(',') : nil)
        end
        it_behaves_like 'OK', :success
      end
      context 'ない' do
        let_it_be(:send_history) { FactoryBot.create(:send_history, send_setting:, target_date:, notice_target:) }
        it_behaves_like 'OK', :success
      end
    end
    shared_examples_for '通知履歴の通知対象' do
      context '開始確認' do
        let_it_be(:notice_target) { :start }
        it_behaves_like '通知履歴のタスクイベント'
      end
      context '翌営業日・終了確認' do
        let_it_be(:notice_target) { :next }
        it_behaves_like '通知履歴のタスクイベント'
      end
    end
    shared_examples_for '通知履歴の対象日' do
      let_it_be(:send_setting) do
        FactoryBot.create(:send_setting, :slack, space:, slack_domain:, slack_mention:,
                                                 start_notice_completed: notice_completed, next_notice_completed: notice_completed)
      end
      context '当日' do
        let_it_be(:target_date) { Time.zone.today }
        let(:add_target_date) { nil }
        it_behaves_like '通知履歴の通知対象'
      end
      context '前日' do
        let_it_be(:target_date) { Time.zone.today - 1.day }
        let(:add_target_date) { "(#{I18n.l(target_date)})" }
        it_behaves_like '通知履歴の通知対象'
      end
    end
    shared_examples_for '通知設定の完了通知' do
      context 'する' do
        let_it_be(:notice_completed) { true }
        it_behaves_like '通知履歴の対象日'
      end
      context 'しない' do
        let_it_be(:notice_completed) { false }
        it_behaves_like '通知履歴の対象日'
      end
    end

    context 'レスポンスが成功' do
      before do
        WebMock.stub_request(:post, send_setting.slack_webhook_url).to_return(
          body: 'ok',
          status: 200
        )
      end
      context '通知設定の(Slack)メンションがある' do
        let_it_be(:slack_mention) { '!here' }
        it_behaves_like '通知設定の完了通知'
      end
      context '通知設定の(Slack)メンションがない' do
        let_it_be(:slack_mention) { nil }
        it_behaves_like '通知設定の完了通知'
      end
    end
    context 'レスポンスが失敗' do
      before do
        WebMock.stub_request(:post, send_setting.slack_webhook_url).to_return(
          body: nil,
          status: 500
        )
      end
      let_it_be(:send_setting) { FactoryBot.create(:send_setting, :slack, space:, slack_domain:) }
      let_it_be(:send_history) { FactoryBot.create(:send_history, send_setting:) }
      it_behaves_like 'OK', :failure
    end
  end
end
