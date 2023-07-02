require 'rails_helper'

RSpec.describe 'TaskEvents', type: :request do
  let(:response_json) { JSON.parse(response.body) }
  let(:response_json_events) { response_json['events'] }
  let(:response_json_tasks)  { response_json['tasks'] }

  # GET /task_events/:space_code(.json) タスクイベント一覧API
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開
  #   権限: ある（管理者〜閲覧者）, ない
  #   開始日: ない, YYYY-MM-DD, YYYY/MM/DD, YYYYMMDD, 存在しない日付（1/0, 2/30）
  #   終了日: ない, YYYY-MM-DD, YYYY/MM/DD, YYYYMMDD, 存在しない日付（1/0, 2/30）, 開始日より前, 開始日と同じ, 最大月数より大きい
  #   イベント・タスク: ある, ない
  #     作成者: いる, アカウント削除済み
  #     最終更新者: いない, いる, アカウント削除済み
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'GET #index' do
    subject do
      travel_to(current_date) do
        get task_events_path(space_code: space.code, format: subject_format), params:, headers: auth_headers.merge(accept_headers)
      end
    end
    Settings.task_events_max_month_count = 3 # NOTE: 3ヶ月分で検証

    let_it_be(:current_date) { Date.new(2022, 12, 30) }
    include_context '祝日設定(2022/11-2023/01)'

    let_it_be(:space_not)     { FactoryBot.build_stubbed(:space) }
    let_it_be(:space_public)  { FactoryBot.create(:space, :public) }
    let_it_be(:space_private) { FactoryBot.create(:space, :private, created_user: space_public.created_user) }
    let_it_be(:created_user)      { FactoryBot.create(:user) }
    let_it_be(:last_updated_user) { FactoryBot.create(:user) }
    let_it_be(:destroy_user)      { FactoryBot.build_stubbed(:user) }
    let(:valid_start_date) { current_date.beginning_of_month }
    let(:valid_end_date)   { (valid_start_date + (Settings.task_events_max_month_count - 1).months).end_of_month } # NOTE: 最大月数
    let(:valid_params) { { start_date: valid_start_date.strftime('%Y-%m-%d'), end_date: valid_end_date.strftime('%Y-%m-%d') } }

    # テスト内容
    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)
        expect(response_json['success']).to eq(true)
        expect(response_json['search_params']).to eq({ start_date: search_start_date, end_date: search_end_date }.stringify_keys)

        expect(response_json_events.count).to eq(expect_events.count)
        response_json_events.each_with_index do |response_json_event, index|
          task_cycle = task_cycles[expect_events[index][:index]]
          task_event = expect_events[index][:task_event]
          count = expect_task_event_json(response_json_event, task_cycle.task, task_cycle, task_event, expect_events[index], { detail: false })
          expect(response_json_event.count).to eq(count)
        end

        expect(response_json_tasks.count).to eq(expect_tasks.count)
        response_json_tasks.each_with_index do |response_json_task, index|
          count = expect_task_json(response_json_task, expect_tasks[index], nil, { detail: false, cycles: false })
          expect(response_json_task.count).to eq(count)
        end

        expect(response_json.count).to eq(4)
      end
    end

    # テストケース
    shared_examples_for 'イベント・タスクがある' do
      let_it_be(:tasks) do
        [
          FactoryBot.create(:task, :skip_validate, :high, space:, started_date: Date.new(2022, 12, 1), ended_date: Date.new(2023, 1, 31),
                                                          created_user_id: destroy_user.id, last_updated_user:),
          FactoryBot.create(:task, :skip_validate, :middle, space:, started_date: Date.new(2022, 12, 30), ended_date: nil,
                                                            created_user:, last_updated_user_id: destroy_user.id),
          FactoryBot.create(:task, :skip_validate, :low, space:, started_date: Date.new(2023, 1, 4), ended_date: nil,
                                                         created_user:, last_updated_user: nil)
        ]
      end
      let_it_be(:task_cycles) do
        [
          FactoryBot.create(:task_cycle, :weekly, task: tasks[0], wday: :tue, handling_holiday: :after, period: 2, order: 1),
          FactoryBot.create(:task_cycle, :monthly, :day, task: tasks[1], day: 1, handling_holiday: :before, period: 1, order: 1),
          FactoryBot.create(:task_cycle, :yearly, :business_day, task: tasks[2], month: 1, business_day: 2, period: 2, order: 1),
          FactoryBot.create(:task_cycle, :yearly, :week, task: tasks[2], month: 2, week: :third, wday: :wed, handling_holiday: :after, period: 3, order: 1)
        ]
      end
      let_it_be(:task_events) do
        [
          FactoryBot.create(:task_event, :completed, task_cycle: task_cycles[0], started_date: Date.new(2022, 12, 5), ended_date: Date.new(2022, 12, 6)),
          FactoryBot.create(:task_event, :assigned, :completed, task_cycle: task_cycles[0], started_date: Date.new(2022, 12, 12), ended_date: Date.new(2022, 12, 13)),
          FactoryBot.create(:task_event, :assigned, task_cycle: task_cycles[0], started_date: Date.new(2022, 12, 19), ended_date: Date.new(2022, 12, 20), last_ended_date: Date.new(2022, 12, 21)),
          FactoryBot.create(:task_event, task_cycle: task_cycles[0], started_date: Date.new(2022, 12, 26), ended_date: Date.new(2022, 12, 27), last_ended_date: Date.new(2022, 12, 30)),
          FactoryBot.create(:task_event, task_cycle: task_cycles[1], started_date: Date.new(2022, 12, 30), ended_date: Date.new(2022, 12, 30))
        ]
      end
      let(:expect_events) do
        return [] if search_start_date == '2023-02-28' && search_end_date == '2023-02-28'

        [
          { index: 0, started_date: '2022-12-05', last_ended_date: '2022-12-06', task_event: task_events[0] },
          { index: 0, started_date: '2022-12-12', last_ended_date: '2022-12-13', task_event: task_events[1] },
          { index: 0, started_date: '2022-12-19', last_ended_date: '2022-12-21', task_event: task_events[2] }, # <- last_ended_date: '2022-12-20'
          { index: 0, started_date: '2022-12-26', last_ended_date: '2022-12-30', task_event: task_events[3] }, # <- , last_ended_date: '2022-12-27'
          { index: 1, started_date: '2022-12-30', last_ended_date: '2022-12-30', task_event: task_events[4] },
          { index: 0, started_date: '2022-12-30', last_ended_date: '2023-01-03' }, # NOTE: 祝日の為 <- started_date: '2023-01-02'
          { index: 0, started_date: '2023-01-06', last_ended_date: '2023-01-10' }, # NOTE: 祝日の為 <- started_date: '2023-01-09'
          { index: 0, started_date: '2023-01-16', last_ended_date: '2023-01-17' },
          { index: 0, started_date: '2023-01-23', last_ended_date: '2023-01-24' },
          { index: 0, started_date: '2023-01-30', last_ended_date: '2023-01-31' },
          { index: 1, started_date: '2023-02-01', last_ended_date: '2023-02-01' },
          { index: 2, started_date: '2023-01-03', last_ended_date: '2023-01-04' },
          { index: 3, started_date: '2023-02-13', last_ended_date: '2023-02-15' }
        ]
      end
      let(:expect_tasks) do
        return [] if search_start_date == '2023-02-28' && search_end_date == '2023-02-28'

        tasks
      end
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToOK(json)'
    end
    shared_examples_for 'イベント・タスクがない' do
      let(:expect_events) { [] }
      let(:expect_tasks) { [] }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToOK(json)'
    end

    shared_examples_for '終了日' do
      context 'ない' do
        let(:end_date) { nil }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToNG(json)', 422, { end_date: [get_locale('errors.messages.param.blank')] }, 'errors.messages.default'
      end
      context 'YYYY-MM-DD' do
        let(:end_date)        { valid_end_date.strftime('%Y-%m-%d') }
        let(:search_end_date) { end_date }
        it_behaves_like 'イベント・タスクがある'
        # it_behaves_like 'イベント・タスクがない' # NOTE: 'YYYY/MM/DD'と同じなので省略
      end
      context 'YYYY/MM/DD' do
        let(:end_date)        { valid_end_date.strftime('%Y/%m/%d') }
        let(:search_end_date) { valid_end_date.strftime('%Y-%m-%d') }
        # it_behaves_like 'イベント・タスクがある' # NOTE: 'YYYY-MM-DD'と同じなので省略
        it_behaves_like 'イベント・タスクがない'
      end
      context 'YYYYMMDD' do
        let(:end_date)        { valid_end_date.strftime('%Y%m%d') }
        let(:search_end_date) { valid_end_date.strftime('%Y-%m-%d') }
        # it_behaves_like 'イベント・タスクがある' # NOTE: 'YYYY-MM-DD'と同じなので省略
        it_behaves_like 'イベント・タスクがない'
      end
      context '存在しない日付（1/0）' do
        let(:end_date) { '2023-01-00' }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToNG(json)', 422, { end_date: [get_locale('errors.messages.param.invalid')] }, 'errors.messages.default'
      end
      context '存在しない日付（2/30）' do
        let(:end_date)        { '2023-02-30' } # NOTE: 月末で処理
        let(:search_end_date) { '2023-02-28' }
        # it_behaves_like 'イベント・タスクがある' # NOTE: '終了日が開始日と同じ'と同じなので省略
        it_behaves_like 'イベント・タスクがない'
      end
      context '終了日が開始日より前' do
        let(:end_date)        { (search_start_date.to_date - 1.day).strftime('%Y-%m-%d') }
        let(:search_end_date) { end_date }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToNG(json)', 422, { end_date: [get_locale('errors.messages.task_events.end_date.after')] }, 'errors.messages.default'
      end
      context '終了日が開始日と同じ' do
        let(:end_date)        { start_date }
        let(:search_end_date) { search_start_date }
        # it_behaves_like 'イベント・タスクがある' # NOTE: '存在しない日付（2/30）'と同じなので省略
        it_behaves_like 'イベント・タスクがない'
      end
      context '終了日が最大月数より大きい' do
        let(:end_date) { (search_start_date.to_date + Settings.task_events_max_month_count.months).beginning_of_month.strftime('%Y-%m-%d') }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToNG(json)', 422, { end_date: [get_locale('errors.messages.task_events.max_month_count', count: Settings.task_events_max_month_count)] }, 'errors.messages.default'
      end
    end

    shared_examples_for '開始日' do
      let(:params) { { start_date:, end_date: } }
      context 'ない' do
        let(:start_date) { nil }
        let(:end_date)   { valid_params[:end_date] }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToNG(json)', 422, { start_date: [get_locale('errors.messages.param.blank')] }, 'errors.messages.default'
      end
      context 'YYYY-MM-DD' do
        let(:start_date)        { valid_start_date.strftime('%Y-%m-%d') }
        let(:search_start_date) { start_date }
        it_behaves_like '終了日'
      end
      context 'YYYY/MM/DD' do
        let(:start_date)        { valid_start_date.strftime('%Y/%m/%d') }
        let(:search_start_date) { valid_start_date.strftime('%Y-%m-%d') }
        it_behaves_like '終了日'
      end
      context 'YYYYMMDD' do
        let(:start_date)        { valid_start_date.strftime('%Y%m%d') }
        let(:search_start_date) { valid_start_date.strftime('%Y-%m-%d') }
        it_behaves_like '終了日'
      end
      context '存在しない日付（1/0）' do
        let(:start_date) { '2023-01-00' }
        let(:end_date)   { valid_params[:end_date] }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToNG(json)', 422, { start_date: [get_locale('errors.messages.param.invalid')] }, 'errors.messages.default'
      end
      context '存在しない日付（2/30）' do
        let(:start_date)        { '2023-02-30' }
        let(:search_start_date) { '2023-02-28' }
        it_behaves_like '終了日' # NOTE: 月末で処理
      end
    end

    shared_examples_for '[APIログイン中/削除予約済み][非公開]権限がある' do |power|
      before_all { FactoryBot.create(:member, power, space:, user:) }
      it_behaves_like '開始日'
    end
    shared_examples_for '[APIログイン中/削除予約済み][非公開]権限がない' do
      let(:params) { valid_params }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[*]スペースが存在しない' do
      let_it_be(:space) { space_not }
      let(:params) { valid_params }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 404
    end
    shared_examples_for '[*]スペースが公開' do
      let_it_be(:space) { space_public }
      it_behaves_like '開始日'
    end
    shared_examples_for '[未ログイン]スペースが非公開' do
      let_it_be(:space) { space_private }
      let(:params) { valid_params }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 401
    end
    shared_examples_for '[APIログイン中/削除予約済み]スペースが非公開' do
      let_it_be(:space) { space_private }
      it_behaves_like '[APIログイン中/削除予約済み][非公開]権限がある', :admin
      it_behaves_like '[APIログイン中/削除予約済み][非公開]権限がある', :reader
      it_behaves_like '[APIログイン中/削除予約済み][非公開]権限がない'
    end

    shared_examples_for '[APIログイン中/削除予約済み]' do
      it_behaves_like '[*]スペースが存在しない'
      it_behaves_like '[*]スペースが公開'
      it_behaves_like '[APIログイン中/削除予約済み]スペースが非公開'
    end

    context '未ログイン' do
      include_context '未ログイン処理'
      it_behaves_like '[*]スペースが存在しない'
      it_behaves_like '[*]スペースが公開'
      it_behaves_like '[未ログイン]スペースが非公開'
    end
    context 'APIログイン中' do
      include_context 'APIログイン処理'
      it_behaves_like '[APIログイン中/削除予約済み]'
    end
    context 'APIログイン中（削除予約済み）' do
      include_context 'APIログイン処理', :destroy_reserved
      it_behaves_like '[APIログイン中/削除予約済み]'
    end
  end
end
