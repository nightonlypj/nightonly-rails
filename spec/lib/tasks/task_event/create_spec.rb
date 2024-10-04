require 'rake_helper'

RSpec.describe :task_event, type: :task do
  # 期間内のタスクイベント作成＋通知（作成・通知は開始時間以降）
  # テストパターン
  #   ドライラン: true, false
  describe 'task_event:create_send_notice:now' do
    subject { Rake.application['task_event:create_send_notice:now'].invoke(dry_run) }

    # テスト内容
    shared_examples_for 'OK' do
      it '正常終了' do
        expect { subject }.not_to raise_error
      end
    end

    # テストケース
    context 'ドライランtrue' do
      let(:dry_run) { 'true' }
      it_behaves_like 'OK'
    end
    context 'ドライランtrue' do
      let(:dry_run) { 'true' }
      it_behaves_like 'OK'
    end
  end

  # 期間内のタスクイベント作成＋通知（当日に実行できなかった場合に手動実行）
  # 前提条件
  #   スペース・タスクがある
  # テストパターン
  #   対象日: ない, 不正値, 前日（営業日, 休日）, 当日（営業日, 休日）, 翌日
  #   実行時間: (開始確認)開始時間より前, (開始確認)開始時間より後, (翌営業日・終了確認)開始時間より後
  #   タスク担当者: いない, いる
  #     ユーザーIDs: ない, 閲覧者, [投稿者], 閲覧者+[管理者], [投稿者]+削除済み, [投稿者]+[管理者], 削除予定+[管理者]+[投稿者]+未参加
  #   タスク周期: ある, ない
  #   通知設定: ない, ある
  #     (開始確認/翌営業日・終了確認)必ず通知: する, しない
  #     (開始確認/翌営業日・終了確認)完了通知: する, しない
  #   通知履歴
  #     開始確認/翌営業日・終了確認: 未通知, 通知済み, 通知エラー
  #   ドライラン: true, false
  #   通知: true, false
  describe 'task_event:create_send_notice' do
    subject { travel_to(current_time) { Rake.application['task_event:create_send_notice'].invoke(target_date, dry_run, send_notice) } }

    let_it_be(:current_date) { Date.new(2022, 12, 30) } # NOTE: 翌日が土曜・休日
    include_context '祝日設定(2022/11-2023/01)'

    let_it_be(:user)  { FactoryBot.create(:user) }
    let_it_be(:space) { FactoryBot.create(:space, created_user: user) }
    let_it_be(:tasks) do
      started_date = Date.new(2022, 12, 1) # NOTE: 年を跨ぐように1/4から変更
      [
        FactoryBot.create(:task, :skip_validate, :high, space:, started_date: Date.new(2023, 1, 3), ended_date: Date.new(2023, 1, 4), created_user: user),
        FactoryBot.create(:task, :skip_validate, :middle, space:, started_date: Date.new(2022, 12, 30), ended_date: Date.new(2023, 1, 3), created_user: user),
        FactoryBot.create(:task, :skip_validate, :low, space:, started_date: Date.new(2023, 1, 3), ended_date: Date.new(2023, 1, 4), created_user: user),
        FactoryBot.create(:task, :skip_validate, :none, space:, started_date:, ended_date: Date.new(2023, 1, 5), created_user: user)
      ]
    end
    before_all do # NOTE: 対象外
      task = FactoryBot.create(:task, :skip_validate, :no_end, space:, started_date: Date.new(2023, 1, 4), created_user: user)
      FactoryBot.create(:task_cycle, :weekly, task:, wday: :mon, handling_holiday: :after, period: 2, holiday: false) # 12/30-1/3（月曜＋翌営業日）
      task = FactoryBot.create(:task, :skip_validate, :no_end, space:, started_date: Date.new(2022, 12, 31), created_user: user)
      FactoryBot.create(:task_cycle, :monthly, :day, task:, day: 2, handling_holiday: :before, period: 1, holiday: false) # 12/30（前営業日）
      task = FactoryBot.create(:task, :skip_validate, :no_end, space:, started_date: Date.new(2023, 1, 4), created_user: user)
      FactoryBot.create(:task_cycle, :yearly, :business_day, task:, month: 1, business_day: 1, period: 3, holiday: false) # 12/30-1/3（第1営業日）
      task = FactoryBot.create(:task, :skip_validate, :no_end, space:, started_date: Date.new(2023, 1, 5), created_user: user)
      FactoryBot.create(:task_cycle, :yearly, :week, task:, month: 1, week: :first, wday: :wed, handling_holiday: :onday, period: 7, holiday: true)
      # 12/30-1/4（第1水曜）
    end

    shared_context 'タスク担当者作成1' do
      before_all do
        FactoryBot.create(:task_assigne, task: tasks[1], user_ids: nil) # ユーザーIDs: ない
        FactoryBot.create(:task_assigne, task: tasks[2], user_ids: user_reader.id.to_s) # ユーザーIDs: 閲覧者
        FactoryBot.create(:task_assigne, task: tasks[3], user_ids: user_writer.id.to_s) # ユーザーIDs: [投稿者]
      end
      let(:except_task_assigne) do
        {
          tasks[0].id => { user_id: nil, user_ids: nil },
          tasks[1].id => { user_id: nil, user_ids: nil },
          tasks[2].id => { user_id: nil, user_ids: user_reader.id.to_s },
          tasks[3].id => { user_id: user_writer.id, user_ids: user_writer.id.to_s }
        }
      end
    end
    shared_context 'タスク担当者作成2' do
      before_all do
        FactoryBot.create(:task_assigne, task: tasks[0], user_ids: "#{user_reader.id},#{user_admin.id}") # ユーザーIDs: 閲覧者+[管理者]
        FactoryBot.create(:task_assigne, task: tasks[1], user_ids: "#{user_writer.id},#{user_destroy.id}") # ユーザーIDs: [投稿者]+削除済み
        FactoryBot.create(:task_assigne, task: tasks[2], user_ids: "#{user_writer.id},#{user_admin.id}") # ユーザーIDs: [投稿者]+[管理者]
        user_ids = "#{user_destroy_reserved.id},#{user_admin.id},#{user_writer.id},#{user.id}" # ユーザーIDs: 削除予定+[管理者]+[投稿者]+未参加
        FactoryBot.create(:task_assigne, task: tasks[3], user_ids:)
      end
      let(:except_task_assigne) do
        {
          tasks[0].id => { user_id: user_admin.id, user_ids: "#{user_reader.id},#{user_admin.id}" },
          tasks[1].id => { user_id: user_writer.id, user_ids: "#{user_destroy.id},#{user_writer.id}" },
          tasks[2].id => { user_id: user_writer.id, user_ids: "#{user_admin.id},#{user_writer.id}" },
          tasks[3].id => { user_id: user_admin.id, user_ids: "#{user_writer.id},#{user.id},#{user_destroy_reserved.id},#{user_admin.id}" }
        }
      end
    end

    shared_context 'タスク周期作成' do |create = { today: false, next: false }|
      let_it_be(:today_task_cycles) do
        next [] unless create[:today]

        [
          FactoryBot.create(:task_cycle, :weekly, task: tasks[0], wday: :mon, handling_holiday: :after, period: 2, holiday: false), # 12/30-1/3（月曜＋翌営業日）
          FactoryBot.create(:task_cycle, :monthly, :day, task: tasks[1], day: 2, handling_holiday: :before, period: 1, holiday: false), # 12/30（前営業日）
          FactoryBot.create(:task_cycle, :yearly, :business_day, task: tasks[2], month: 1, business_day: 1, period: 2, holiday: false), # 12/30-1/3（第1営業日）
          FactoryBot.create(:task_cycle, :yearly, :week, task: tasks[3], month: 1, week: :first, wday: :wed, handling_holiday: :onday, period: 6, holiday: true)
          # 12/30-1/4（第1水曜）
        ]
      end
      let_it_be(:except_today_task_events) do
        next [] unless create[:today]

        started_date = Date.new(2022, 12, 30)
        [
          { task_cycle_id: today_task_cycles[0].id, started_date:, ended_date: Date.new(2023, 1, 3) },
          { task_cycle_id: today_task_cycles[1].id, started_date:, ended_date: Date.new(2022, 12, 30) },
          { task_cycle_id: today_task_cycles[2].id, started_date:, ended_date: Date.new(2023, 1, 3) },
          { task_cycle_id: today_task_cycles[3].id, started_date:, ended_date: Date.new(2023, 1, 4) }
        ]
      end
      let_it_be(:next_task_cycles) do
        next [] unless create[:next]

        [
          FactoryBot.create(:task_cycle, :weekly, task: tasks[0], wday: :wed, handling_holiday: :before, period: 2, holiday: false), # 1/3-4（水曜）
          FactoryBot.create(:task_cycle, :monthly, :day, task: tasks[1], day: 31, handling_holiday: :after, period: 1, holiday: false), # 1/3（後営業日）
          FactoryBot.create(:task_cycle, :yearly, :business_day, task: tasks[2], month: 1, business_day: 2, period: 2, holiday: false), # 11/3-4（第2営業日）
          FactoryBot.create(:task_cycle, :yearly, :week, task: tasks[3], month: 1, week: :first, wday: :thu, handling_holiday: :onday, period: 3, holiday: true)
          # 1/3-5（第1木曜）
        ]
      end
      let_it_be(:except_next_task_events) do
        next [] unless create[:next]

        started_date = Date.new(2023, 1, 3)
        [
          { task_cycle_id: next_task_cycles[0].id, started_date:, ended_date: Date.new(2023, 1, 4) },
          { task_cycle_id: next_task_cycles[1].id, started_date:, ended_date: Date.new(2023, 1, 3) },
          { task_cycle_id: next_task_cycles[2].id, started_date:, ended_date: Date.new(2023, 1, 4) },
          { task_cycle_id: next_task_cycles[3].id, started_date:, ended_date: Date.new(2023, 1, 5) }
        ]
      end
    end

    shared_context 'タスクイベント作成' do |create = { expired: false, today: false, next: false }|
      let_it_be(:expired_task_events) do
        next [] unless create[:expired]

        [FactoryBot.create(:task_event, :waiting_premise, space:, started_date: target_date - 1.day, ended_date: target_date - 1.day)] # 12/29
      end
      let_it_be(:end_today_task_events) do
        next [] unless create[:today]

        [FactoryBot.create(:task_event, :processing, :assigned, **except_today_task_events[1], last_updated_user: user)]
      end
      let_it_be(:date_include_task_events) do
        result = []
        if create[:today]
          result.push(FactoryBot.create(:task_event, :untreated, **except_today_task_events[0]))
          result.push(FactoryBot.create(:task_event, :waiting_premise, **except_today_task_events[2]))
        end
        if create[:next]
          result.push(FactoryBot.create(:task_event, :processing, :assigned, **except_next_task_events[1], last_updated_user: user))
          result.push(FactoryBot.create(:task_event, :untreated, **except_next_task_events[0]))
          result.push(FactoryBot.create(:task_event, :waiting_premise, **except_next_task_events[2]))
        end

        result
      end
      let_it_be(:completed_task_events) do
        result = []
        if create[:today]
          result.push(FactoryBot.create(:task_event, :completed, :assigned, **except_today_task_events[3], last_completed_at: current_date.to_time))
        end
        if create[:next]
          result.push(FactoryBot.create(:task_event, :completed, :assigned, **except_next_task_events[3], last_completed_at: current_date.to_time))
        end

        result
      end
      let_it_be(:task_events) { end_today_task_events + date_include_task_events + completed_task_events }
    end

    include_context 'メンバーパターン作成(user)'
    include_context 'メンバーパターン作成(member)'

    # テスト内容
    let(:current_task_events) { TaskEvent.where(space:).eager_load(task_cycle: { task: :task_assigne }).order(:id) }
    let(:current_send_histories) { SendHistory.where(space:).order(:id) }
    shared_examples_for 'OK' do |notice_target, create = { history: true, send: true }, params = { dry_run: false, send_notice: true }|
      let(:dry_run) { params[:dry_run].to_s }
      let(:send_notice) { params[:send_notice].to_s }
      before { allow(NoticeSlack::IncompleteTaskJob).to receive(:perform_later).and_return(true) }
      it '対象のタスクイベントが作成・対象項目が設定される。NoticeSlack::IncompleteTaskJobが呼ばれる/呼ばれない。メールが送信される/されない' do
        subject
        next_task_event_ids = []
        expired_task_event_ids = []
        end_today_task_event_ids = []
        date_include_task_event_ids = []
        completed_task_event_ids = []

        expect(current_task_events.count - expired_task_events.count).to eq(params[:dry_run] ? 0 : except_task_events.count)
        (current_task_events - expired_task_events - task_events).each.with_index(task_events.count) do |current_task_event, index|
          except_task_cycle = except_task_events[index]
          expect(current_task_event.task_cycle_id).to eq(except_task_cycle[:task_cycle_id])
          expect(current_task_event.started_date).to eq(except_task_cycle[:started_date])
          expect(current_task_event.ended_date).to eq(except_task_cycle[:ended_date])
          expect(current_task_event.last_ended_date).to eq(except_task_cycle[:ended_date])
          expect(current_task_event.last_completed_at).to be_nil
          expect(current_task_event.status.to_sym).to eq(:untreated)

          task_id = current_task_event.task_cycle.task_id
          assigne_user_ids = except_task_assigne[task_id].present? ? except_task_assigne[task_id][:user_ids] : nil
          expect(current_task_event.task_cycle.task.task_assigne&.user_ids).to eq(assigne_user_ids)

          assigned_user_id = except_task_assigne[task_id].present? ? except_task_assigne[task_id][:user_id] : nil
          expect(current_task_event.init_assigned_user_id).to eq(assigned_user_id)
          expect(current_task_event.assigned_user_id).to eq(assigned_user_id)
          expect(current_task_event.assigned_at).to assigned_user_id.present? ? be_between(current_time, current_time + 1.minute) : be_nil
          expect(current_task_event.memo).to be_nil
          expect(current_task_event.last_updated_user_id).to be_nil
          next unless create[:history]

          if notice_target == :next
            next_task_event_ids.push(current_task_event.id)
          elsif current_task_event.ended_date == target_date
            end_today_task_event_ids.push(current_task_event.id)
          else
            date_include_task_event_ids.push(current_task_event.id)
          end
        end

        if create[:history]
          expired_task_event_ids += expired_task_events.pluck(:id)
          end_today_task_event_ids += end_today_task_events.pluck(:id)
          date_include_task_event_ids += date_include_task_events.pluck(:id)
          completed_task_event_ids += completed_task_events.pluck(:id)
          target_count = next_task_event_ids.count + expired_task_event_ids.count + end_today_task_event_ids.count + date_include_task_event_ids.count
          target_count += completed_task_event_ids.count if send_setting.present? && send_setting["#{notice_target}_notice_completed"]

          send_targets = []
          if params[:send_notice]
            send_targets.push(:slack) if send_setting.slack_enabled
            send_targets.push(:email) if send_setting.email_enabled
          end

          expect(current_send_histories.count - send_histories.count).to eq(send_targets.count)
          (current_send_histories - send_histories).each_with_index do |current_send_history, index|
            expect(current_send_history.send_setting).to eq(send_setting)
            expect(current_send_history.target_date).to eq(target_date)
            expect(current_send_history.notice_target.to_sym).to eq(notice_target)
            expect(current_send_history.send_target.to_sym).to eq(send_targets[index])
            if create[:send]
              expect(current_send_history.status.to_sym).to eq(send_targets[index] == :email ? :success : :waiting)
            else
              expect(current_send_history.status.to_sym).to eq(:skip)
            end
            expect(current_send_history.started_at).to be_between(current_time, current_time + 1.minute)
            enable_completed_at = !create[:send] || send_targets[index] == :email
            expect(current_send_history.completed_at).to enable_completed_at ? be_between(current_time, current_time + 1.minute) : be_nil

            expect(current_send_history.target_count).to eq(target_count)
            expect(current_send_history.next_task_event_ids).to next_task_event_ids.present? ? eq(next_task_event_ids.join(',')) : be_nil
            expect(current_send_history.expired_task_event_ids).to expired_task_event_ids.present? ? eq(expired_task_event_ids.join(',')) : be_nil
            expect(current_send_history.end_today_task_event_ids).to end_today_task_event_ids.present? ? eq(end_today_task_event_ids.join(',')) : be_nil
            data = current_send_history.date_include_task_event_ids
            expect(data).to date_include_task_event_ids.present? ? eq(date_include_task_event_ids.join(',')) : be_nil
            if send_setting.present? && send_setting["#{notice_target}_notice_completed"]
              expect(current_send_history.completed_task_event_ids).to completed_task_event_ids.present? ? eq(completed_task_event_ids.join(',')) : be_nil
            else
              expect(current_send_history.completed_task_event_ids).to be_nil
            end
            expect(current_send_history.error_message).to be_nil
            expect(current_send_history.send_data).to(create[:send] && send_targets[index] == :email ? be_present : be_nil)

            if create[:send] && current_send_history.send_target.to_sym == :slack
              expect(NoticeSlack::IncompleteTaskJob).to have_received(:perform_later).with(current_send_history.id)
            end
          end
          expect(NoticeSlack::IncompleteTaskJob).to have_received(:perform_later).exactly(create[:send] && send_targets.include?(:slack) ? 1 : 0).time

          send_mail = create[:send] && send_targets.include?(:email)
          expect(ActionMailer::Base.deliveries.count).to eq(send_mail ? 1 : 0)
          if send_mail
            mail_subject = get_subject('mailer.notice.incomplete_task.subject',
                                       app_name: I18n.t('app_name'), env_name: Settings.env_name || '', space_name: send_setting.space.name)
            expect(ActionMailer::Base.deliveries[0].subject).to eq(mail_subject) # %{name} の未完了のタスクをお知らせします。
          end
        else
          expect(current_send_histories.count - send_histories.count).to eq(0)
          expect(NoticeSlack::IncompleteTaskJob).to have_received(:perform_later).exactly(0).time
          expect(ActionMailer::Base.deliveries.count).to eq(0)
        end
      end
    end

    shared_examples_for '通知履歴作成' do |status|
      let_it_be(:send_histories) do
        [
          FactoryBot.create(:send_history, :start, :slack, status, send_setting:, target_date:),
          FactoryBot.create(:send_history, :start, :email, status, send_setting:, target_date:)
        ]
      end
    end

    # テストケース
    shared_examples_for '[当日（営業日）][(翌営業日・終了確認)開始時間より後][ある][*][通知済み/エラー]翌営業日・終了確認' do |status|
      let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_completed:) }
      let_it_be(:send_histories_start) do
        [
          FactoryBot.create(:send_history, :start, :slack, status, send_setting:, target_date:),
          FactoryBot.create(:send_history, :start, :email, status, send_setting:, target_date:)
        ]
      end
      context '未通知' do
        let(:send_histories) { send_histories_start }
        it_behaves_like 'OK', :next, { history: true, send: true }
      end
      context '通知済み' do
        let_it_be(:send_histories) do
          send_histories_start + [
            FactoryBot.create(:send_history, :next, :slack, :success, send_setting:, target_date:),
            FactoryBot.create(:send_history, :next, :email, :success, send_setting:, target_date:)
          ]
        end
        it_behaves_like 'OK', :next, { history: false, send: false }
      end
      context '通知エラー' do
        let_it_be(:send_histories) do
          send_histories_start + [
            FactoryBot.create(:send_history, :next, :slack, :failure, send_setting:, target_date:),
            FactoryBot.create(:send_history, :next, :email, :failure, send_setting:, target_date:)
          ]
        end
        it_behaves_like 'OK', :next, { history: true, send: true }
      end
    end

    shared_examples_for '[当日（営業日）][(開始確認)開始時間より後][ある][ある][*]開始確認' do
      let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:, start_notice_completed:) }
      context '未通知' do
        let(:send_histories) { [] }
        it_behaves_like 'OK', :start, { history: true, send: true }
      end
      context '通知済み' do
        include_context '通知履歴作成', :success
        it_behaves_like 'OK', :start, { history: false, send: false }
      end
      context '通知エラー' do
        include_context '通知履歴作成', :failure
        it_behaves_like 'OK', :start, { history: true, send: true }
      end
    end
    shared_examples_for '[当日（営業日）][(翌営業日・終了確認)開始時間より後][ある][ある][*]開始確認' do
      context '未通知' do
        let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_completed:) }
        let(:send_histories) { [] }
        it_behaves_like 'OK', :next, { history: true, send: true }
      end
      context '通知済み' do
        it_behaves_like '[当日（営業日）][(翌営業日・終了確認)開始時間より後][ある][*][通知済み/エラー]翌営業日・終了確認', :success
      end
      context '通知エラー' do
        it_behaves_like '[当日（営業日）][(翌営業日・終了確認)開始時間より後][ある][*][通知済み/エラー]翌営業日・終了確認', :failure
      end
    end

    context do # 手動実行
      let(:current_time) { current_date.to_time }
      let(:dry_run) { 'false' }
      let(:send_notice) { 'true' }

      context '対象日がない' do
        let(:target_date) { nil }
        it_behaves_like 'ToRaise', '日付が指定されていません。'
      end
      context '対象日が不正値' do
        let(:target_date) { 'a' }
        it_behaves_like 'ToRaise', '日付の形式が不正です。(invalid date)'
      end
      context '対象日が翌日' do
        let(:target_date) { current_date + 1.day }
        it_behaves_like 'ToRaise', '翌日以降の日付は指定できません。'
      end
    end
    context '対象日が前日（営業日）' do # 手動実行
      let_it_be(:target_date) { current_date - 1.day }
      let(:current_time) { current_date.to_time }
      let(:send_histories) { [] }
      include_context 'タスク担当者作成1'

      context 'タスク周期がある' do
        include_context 'タスク周期作成', { today: true, next: true }
        let(:except_task_events) { except_today_task_events }
        include_context 'タスクイベント作成', { expired: true, today: false, next: false }

        context '通知設定がない' do
          let(:send_setting) { nil }
          it_behaves_like 'OK', nil, { history: false, send: false }
        end
        context '通知設定がある' do
          let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:) }
          it_behaves_like 'OK', :next, { history: true, send: true }, { dry_run: false, send_notice: true }
          it_behaves_like 'OK', :next, { history: true, send: false }, { dry_run: false, send_notice: false }
          it_behaves_like 'OK', :next, { history: false, send: false }, { dry_run: true, send_notice: true }
        end
      end
      context 'タスク周期がない' do
        let(:except_task_events) { [] }
        include_context 'タスクイベント作成', { expired: false, today: false, next: false }

        context '通知設定がない' do
          let(:send_setting) { nil }
          it_behaves_like 'OK', nil, { history: false, send: false }
        end
        context '通知設定がある（必ず通知する）' do
          let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_required: true) }
          it_behaves_like 'OK', :next, { history: true, send: true }, { dry_run: false, send_notice: true }
          it_behaves_like 'OK', :next, { history: true, send: false }, { dry_run: false, send_notice: false }
          it_behaves_like 'OK', :next, { history: false, send: false }, { dry_run: true, send_notice: true }
        end
        context '通知設定がある（必ずしも通知しない）' do
          let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_required: false) }
          it_behaves_like 'OK', :next, { history: true, send: false }, { dry_run: false, send_notice: true }
          it_behaves_like 'OK', :next, { history: true, send: false }, { dry_run: false, send_notice: false }
          it_behaves_like 'OK', :next, { history: false, send: false }, { dry_run: true, send_notice: true }
        end
      end
    end
    context '対象日が前日（休日）' do # 手動実行
      let_it_be(:target_date) { current_date - 1.day }
      before_all { FactoryBot.create(:holiday, date: target_date, name: '休日') }
      let(:current_time) { current_date.to_time }
      let(:send_histories) { [] }
      include_context 'タスク担当者作成2'

      context 'タスク周期がある' do
        include_context 'タスク周期作成', { today: true, next: true }
        let(:except_task_events) { except_today_task_events }
        include_context 'タスクイベント作成', { expired: true, today: false, next: false }

        context '通知設定がない' do
          let(:send_setting) { nil }
          it_behaves_like 'OK', nil, { history: false, send: false }
        end
        context '通知設定がある' do
          let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:) }
          it_behaves_like 'OK', nil, { history: false, send: false }
        end
      end
      context 'タスク周期がない' do
        let(:except_task_events) { [] }
        include_context 'タスクイベント作成', { expired: false, today: false, next: false }

        context '通知設定がない' do
          let(:send_setting) { nil }
          it_behaves_like 'OK', nil, { history: false, send: false }
        end
        context '通知設定がある（必ず通知する）' do
          let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_required: true) }
          it_behaves_like 'OK', nil, { history: false, send: false }
        end
        context '通知設定がある（必ずしも通知しない）' do
          let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_required: false) }
          it_behaves_like 'OK', nil, { history: false, send: false }
        end
      end
    end
    context '対象日が当日（営業日）' do # 自動実行
      let_it_be(:target_date) { current_date }
      context '実行時間が(開始確認)開始時間より前' do
        let(:send_histories) { [] }
        include_context 'タスク担当者作成1'

        context 'タスク周期がある' do
          include_context 'タスク周期作成', { today: true, next: true }
          let(:except_task_events) { except_today_task_events }
          include_context 'タスクイベント作成', { expired: true, today: false, next: false }

          context '通知設定がない' do
            let(:send_setting) { nil }
            let(:current_time) { current_date + (Settings.default_start_notice_start_hour - 1).hours }
            it_behaves_like 'OK', nil, { history: false, send: false }
          end
          context '通知設定がある' do
            let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:) }
            let(:current_time) { current_date + (send_setting.start_notice_start_hour - 1).hours }
            it_behaves_like 'OK', nil, { history: false, send: false }
          end
        end
        context 'タスク周期がない' do
          let(:except_task_events) { [] }
          include_context 'タスクイベント作成', { expired: false, today: false, next: false }

          context '通知設定がない' do
            let(:send_setting) { nil }
            let(:current_time) { current_date + (Settings.default_start_notice_start_hour - 1).hours }
            it_behaves_like 'OK', nil, { history: false, send: false }
          end
          context '通知設定がある（必ず通知する）' do
            let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_required: true) }
            let(:current_time) { current_date + (send_setting.start_notice_start_hour - 1).hours }
            it_behaves_like 'OK', nil, { history: false, send: false }
          end
          context '通知設定がある（必ずしも通知しない）' do
            let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_required: false) }
            let(:current_time) { current_date + (send_setting.start_notice_start_hour - 1).hours }
            it_behaves_like 'OK', nil, { history: false, send: false }
          end
        end
      end
      context '実行時間が(開始確認)開始時間より後' do
        include_context 'タスク担当者作成2'

        context 'タスク周期がある' do
          include_context 'タスク周期作成', { today: true, next: true }
          let_it_be(:except_task_events) { except_today_task_events }
          include_context 'タスクイベント作成', { expired: true, today: false, next: false }

          context '通知設定がない' do
            let(:send_setting) { nil }
            let(:current_time) { current_date + Settings.default_start_notice_start_hour.hours }
            let(:send_histories) { [] }
            it_behaves_like 'OK', nil, { history: false, send: false }
          end
          context '通知設定がある' do
            let(:current_time) { current_date + send_setting.start_notice_start_hour.hours }
            context '完了通知する' do
              let_it_be(:start_notice_completed) { true }
              it_behaves_like '[当日（営業日）][(開始確認)開始時間より後][ある][ある][*]開始確認'
            end
            context '完了通知しない' do
              let_it_be(:start_notice_completed) { false }
              it_behaves_like '[当日（営業日）][(開始確認)開始時間より後][ある][ある][*]開始確認'
            end
          end
        end
        context 'タスク周期がない' do
          let(:except_task_events) { [] }
          include_context 'タスクイベント作成', { expired: false, today: false, next: false }
          let(:send_histories) { [] }

          context '通知設定がない' do
            let(:send_setting) { nil }
            let(:current_time) { current_date + Settings.default_start_notice_start_hour.hours }
            it_behaves_like 'OK', nil, { history: false, send: false }
          end
          context '通知設定がある（必ず通知する）' do
            let(:current_time) { current_date + send_setting.start_notice_start_hour.hours }
            context '完了通知する' do
              let_it_be(:send_setting) do
                FactoryBot.create(:send_setting, :changed, :slack, :email, space:, start_notice_required: true, start_notice_completed: true)
              end
              it_behaves_like 'OK', :start, { history: true, send: true }
            end
            context '完了通知しない' do
              let_it_be(:send_setting) do
                FactoryBot.create(:send_setting, :changed, :slack, :email, space:, start_notice_required: true, start_notice_completed: false)
              end
              it_behaves_like 'OK', :start, { history: true, send: true }
            end
          end
          context '通知設定がある（必ずしも通知しない）' do
            let(:current_time) { current_date + send_setting.start_notice_start_hour.hours }
            context '完了通知する' do
              let_it_be(:send_setting) do
                FactoryBot.create(:send_setting, :changed, :slack, :email, space:, start_notice_required: false, start_notice_completed: true)
              end
              it_behaves_like 'OK', :start, { history: true, send: false }
            end
            context '完了通知しない' do
              let_it_be(:send_setting) do
                FactoryBot.create(:send_setting, :changed, :slack, :email, space:, start_notice_required: false, start_notice_completed: false)
              end
              it_behaves_like 'OK', :start, { history: true, send: false }
            end
          end
        end
      end
      context '実行時間が(翌営業日・終了確認)開始時間より後' do
        include_context 'タスク担当者作成1'

        context 'タスク周期がある' do
          include_context 'タスク周期作成', { today: true, next: true }
          let_it_be(:except_task_events) { except_today_task_events + except_next_task_events }
          include_context 'タスクイベント作成', { expired: false, today: true, next: false }

          context '通知設定がない' do
            let(:send_setting) { nil }
            let(:current_time) { current_date + Settings.default_next_notice_start_hour.hours }
            let(:send_histories) { [] }
            it_behaves_like 'OK', nil, { history: false, send: false }
          end
          context '通知設定がある' do
            let(:current_time) { current_date + send_setting.next_notice_start_hour.hours }
            context '完了通知する' do
              let_it_be(:next_notice_completed) { true }
              it_behaves_like '[当日（営業日）][(翌営業日・終了確認)開始時間より後][ある][ある][*]開始確認'
            end
            context '完了通知しない' do
              let_it_be(:next_notice_completed) { false }
              it_behaves_like '[当日（営業日）][(翌営業日・終了確認)開始時間より後][ある][ある][*]開始確認'
            end
          end
        end
        context 'タスク周期がない' do
          let(:except_task_events) { [] }
          include_context 'タスクイベント作成', { expired: false, today: false, next: false }
          let(:send_histories) { [] }

          context '通知設定がない' do
            let(:send_setting) { nil }
            let(:current_time) { current_date + Settings.default_next_notice_start_hour.hours }
            it_behaves_like 'OK', nil, { history: false, send: false }
          end
          context '通知設定がある（必ず通知する）' do
            let(:current_time) { current_date + send_setting.next_notice_start_hour.hours }
            context '完了通知する' do
              let_it_be(:send_setting) do
                FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_required: true, next_notice_completed: true)
              end
              it_behaves_like 'OK', :next, { history: true, send: true }
            end
            context '完了通知しない' do
              let_it_be(:send_setting) do
                FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_required: true, next_notice_completed: false)
              end
              it_behaves_like 'OK', :next, { history: true, send: true }
            end
          end
          context '通知設定がある（必ずしも通知しない）' do
            let(:current_time) { current_date + send_setting.next_notice_start_hour.hours }
            context '完了通知する' do
              let_it_be(:send_setting) do
                FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_required: false, next_notice_completed: true)
              end
              it_behaves_like 'OK', :next, { history: true, send: false }
            end
            context '完了通知しない' do
              let_it_be(:send_setting) do
                FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_required: false, next_notice_completed: false)
              end
              it_behaves_like 'OK', :next, { history: true, send: false }
            end
          end
        end
      end
    end
    context '対象日が当日（休日）' do # 自動実行
      let_it_be(:target_date) { current_date + 1.day }
      let(:send_histories) { [] }
      include_context 'タスク担当者作成2'

      context 'タスク周期がある' do
        include_context 'タスク周期作成', { today: true, next: true }
        let_it_be(:except_task_events) { except_today_task_events + except_next_task_events }
        include_context 'タスクイベント作成', { expired: false, today: true, next: true }

        context '通知設定がない' do
          let(:send_setting) { nil }
          let(:current_time) { target_date + Settings.default_next_notice_start_hour.hours }
          it_behaves_like 'OK', nil, { history: false, send: false }
        end
        context '通知設定がある' do
          let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:) }
          let(:current_time) { target_date + send_setting.next_notice_start_hour.hours }
          it_behaves_like 'OK', nil, { history: false, send: false }
        end
      end
      context 'タスク周期がない' do
        let(:except_task_events) { [] }
        include_context 'タスクイベント作成', { expired: false, today: false, next: false }

        context '通知設定がない' do
          let(:send_setting) { nil }
          let(:current_time) { target_date + Settings.default_next_notice_start_hour.hours }
          it_behaves_like 'OK', nil, { history: false, send: false }
        end
        context '通知設定がある（必ず通知する）' do
          let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_required: true) }
          let(:current_time) { target_date + Settings.default_next_notice_start_hour.hours }
          it_behaves_like 'OK', nil, { history: false, send: false }
        end
        context '通知設定がある（必ずしも通知しない）' do
          let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space:, next_notice_required: false) }
          let(:current_time) { target_date + send_setting.next_notice_start_hour.hours }
          it_behaves_like 'OK', nil, { history: false, send: false }
        end
      end
    end
  end
end
