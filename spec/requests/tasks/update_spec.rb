require 'rails_helper'

RSpec.describe 'Tasks', type: :request do
  let(:response_json) { response.parsed_body }
  let(:response_json_task)   { response_json['task'] }
  let(:response_json_events) { response_json['events'] }

  # POST /tasks/:space_code/update/:id(.json) タスク設定変更API(処理)
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開, 非公開（削除予約済み）
  #   権限: ある（管理者, 投稿者）, ない（閲覧者, なし）
  #   タスクID: 存在する, 存在しない
  #   パラメータなし, 有効なパラメータ, 無効なパラメータ
  #     タスク: 正常値, 不正値
  #     周期: 毎週 × 削除なし/あり, 毎月/毎年 × 日/営業日/週
  #       変更なし, 追加あり, 削除・復帰・並び順変更あり
  #     タスク担当者: なし→なし/正常値, いる→正常値（変更あり）/いない, いない→正常値/いない
  #     monthsパラメータ: ない, ある, 空, 不正値
  #     detailパラメータ: ない, true, false
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'POST #update' do
    subject do
      travel_to(current_date) do
        post update_task_path(space_code: space.code, id: task.id, format: subject_format), params:, headers: auth_headers.merge(accept_headers)
      end
    end

    include_context 'タスク作成・更新条件設定'
    include_context 'メンバーパターン作成(user)'
    let_it_be(:valid_task_attributes)  { FactoryBot.attributes_for(:task, started_date: current_date, ended_date: nil) }
    let_it_be(:valid_cycle_attributes) { FactoryBot.attributes_for(:task_cycle).reject { |key| key == :order } }
    let_it_be(:valid_attributes)         { valid_task_attributes.merge(cycles: [valid_cycle_attributes]) }
    let_it_be(:invalid_task_attributes)  { valid_task_attributes.merge(title: nil) }
    let_it_be(:invalid_cycle_attributes) { valid_cycle_attributes.merge(cycle: nil) }
    let_it_be(:valid_task_assigne_users)    { [user_admin, user_writer] }
    let(:valid_assigned_users_attributes)   { [{ code: user_admin.code }, { code: user_writer.code }] }
    let(:invalid_assigned_users_attributes) { [{ code: nil }] }
    let_it_be(:created_user) { FactoryBot.create(:user) }

    shared_context 'valid_condition' do
      let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
      before_all { FactoryBot.create(:member, space:, user:) if user.present? }
      let_it_be(:task) { FactoryBot.create(:task, space:, created_user:) }
      let_it_be(:task_cycles) { [FactoryBot.create(:task_cycle, task:, order: 1)] }
      let(:task_cycle_inactive) { nil }
      let(:params) { { task: valid_attributes } }
    end

    # テスト内容
    let(:current_task)               { Task.eager_load(:task_cycles_active, :task_assigne).find(task.id) }
    let(:current_task_cycles_active) { current_task.task_cycles_active.order(:order, :updated_at, :id) }
    shared_examples_for 'OK' do
      it '対象項目が変更される' do
        subject
        expect(current_task.space).to eq(space)
        expect(current_task.priority.to_sym).to eq(attributes[:priority])
        expect(current_task.title).to eq(attributes[:title])
        expect(current_task.summary).to eq(attributes[:summary])
        expect(current_task.premise).to eq(attributes[:premise])
        expect(current_task.process).to eq(attributes[:process])
        expect(current_task.started_date).to eq(attributes[:started_date])
        expect(current_task.ended_date).to eq(attributes[:ended_date])
        expect(current_task.created_user_id).to be(task.created_user_id)
        expect(current_task.last_updated_user_id).to be(user.id)

        expect(current_task_cycles_active.count).to eq(expect_task_cycles_active.count)
        current_task_cycles_active.each_with_index do |current_task_cycle, index|
          expect(current_task_cycle.space).to eq(space)
          expect(current_task_cycle.task).to eq(current_task)
          expect(current_task_cycle.cycle.to_sym).to eq(expect_task_cycles_active[index][:cycle])
          expect(current_task_cycle.month).to eq(expect_task_cycles_active[index][:month])
          expect(current_task_cycle.target&.to_sym).to eq(expect_task_cycles_active[index][:target])
          expect(current_task_cycle.day).to eq(expect_task_cycles_active[index][:day])
          expect(current_task_cycle.business_day).to eq(expect_task_cycles_active[index][:business_day])
          expect(current_task_cycle.week&.to_sym).to eq(expect_task_cycles_active[index][:week])
          expect(current_task_cycle.wday&.to_sym).to eq(expect_task_cycles_active[index][:wday])
          expect(current_task_cycle.handling_holiday&.to_sym).to eq(expect_task_cycles_active[index][:handling_holiday])
          expect(current_task_cycle.period).to eq(expect_task_cycles_active[index][:period])
          expect(current_task_cycle.holiday).to eq(expect_task_cycles_active[index][:holiday])
          expect(current_task_cycle.order).to eq(index + 1)
          expect(current_task_cycle.deleted_at).to be_nil
        end

        expect(current_task.task_cycles_inactive.count).to eq(except_task_cycle_inactive.present? ? 1 : 0)
        expect(current_task.task_cycles_inactive.first.id).to eq(except_task_cycle_inactive.id) if except_task_cycle_inactive.present?

        expect(current_task.task_assigne&.user_ids).to eq(task_assigne_users&.pluck(:id)&.join(','))
      end
    end
    shared_examples_for 'NG' do
      it '変更されない' do
        subject
        expect(current_task).to eq(task)
        expect(current_task_cycles_active).to eq(task_cycles)
        expect(current_task.task_cycles_inactive.count).to eq(task_cycle_inactive.present? ? 1 : 0)
        expect(current_task.task_cycles_inactive.first).to eq(task_cycle_inactive) if task_cycle_inactive.present?
      end
    end

    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)
        result = 3
        expect(response_json['success']).to be(true)
        expect(response_json['notice']).to eq(get_locale('notice.task.update'))

        if expect_events.present?
          expect(response_json_events.count).to eq(expect_events.count)
          response_json_events.each_with_index do |response_json_event, index|
            current_task_cycle = current_task_cycles_active[expect_events[index][:index]]
            use = { detail: false, email: member&.power_admin? }
            count = expect_task_event_json(response_json_event, current_task, current_task_cycle, nil, expect_events[index], use)
            expect(response_json_event.count).to eq(count)
          end
          result += 1
        else
          expect(response_json_events).to be_nil
        end

        use = { detail: params[:detail], email: member&.power_admin? }
        count = expect_task_json(response_json_task, current_task, expect_events.present? ? nil : current_task_cycles_active, task_assigne_users, use)
        expect(response_json_task.count).to eq(count)

        expect(response_json.count).to eq(result)
      end
    end

    # テストケース
    shared_examples_for '[APIログイン中][*]権限がある' do |power|
      let_it_be(:member) { FactoryBot.create(:member, power, space:, user:) }
      context 'タスクIDが存在する' do
        let_it_be(:task) { FactoryBot.create(:task, space:, created_user:) }
        it_behaves_like 'パラメータなし（タスク）', true
        it_behaves_like '有効なパラメータ（タスク周期）', true
        it_behaves_like '有効なパラメータ（タスク担当者）', true
        it_behaves_like '無効なパラメータ（タスク）', true
      end
      context 'タスクIDが存在しない' do
        let_it_be(:task) { FactoryBot.build_stubbed(:task) }
        let(:params) { { task: valid_attributes } }
        # it_behaves_like 'NG(html)' # NOTE: 存在しない為
        it_behaves_like 'ToNG(html)', 406
        # it_behaves_like 'NG(json)'
        it_behaves_like 'ToNG(json)', 404
      end
    end
    shared_examples_for '[APIログイン中][*]権限がない' do |power|
      before_all { FactoryBot.create(:member, power, space:, user:) if power.present? }
      let_it_be(:task) { FactoryBot.create(:task, space:, created_user:) }
      let_it_be(:task_cycles) { [FactoryBot.create(:task_cycle, task:, order: 1)] }
      let(:task_cycle_inactive) { nil }
      let(:params) { { task: valid_attributes } }
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[APIログイン中][*]' do
      include_context 'メンバーパターン作成(member)'
      it_behaves_like '[APIログイン中][*]権限がある', :admin
      it_behaves_like '[APIログイン中][*]権限がある', :writer
      it_behaves_like '[APIログイン中][*]権限がない', :reader
      it_behaves_like '[APIログイン中][*]権限がない', nil
    end

    shared_examples_for '[APIログイン中]スペースが存在しない' do
      let_it_be(:space) { FactoryBot.build_stubbed(:space) }
      let_it_be(:task) { FactoryBot.build_stubbed(:task) }
      let(:params) { { task: valid_attributes } }
      # it_behaves_like 'NG(html)' # NOTE: 存在しない為
      it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
      # it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 404
    end
    shared_examples_for '[APIログイン中]スペースが公開' do
      let_it_be(:space) { FactoryBot.create(:space, :public, created_user:) }
      it_behaves_like '[APIログイン中][*]'
    end
    shared_examples_for '[APIログイン中]スペースが非公開' do
      let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
      it_behaves_like '[APIログイン中][*]'
    end
    shared_examples_for '[APIログイン中]スペースが非公開（削除予約済み）' do
      let_it_be(:space) { FactoryBot.create(:space, :private, :destroy_reserved, created_user:) }
      before_all { FactoryBot.create(:member, space:, user:) }
      let_it_be(:task) { FactoryBot.create(:task, space:, created_user:) }
      let_it_be(:task_cycles) { [FactoryBot.create(:task_cycle, task:, order: 1)] }
      let(:task_cycle_inactive) { nil }
      let(:params) { { task: valid_attributes } }
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 422, nil, 'alert.space.destroy_reserved'
    end

    context '未ログイン' do
      include_context '未ログイン処理'
      include_context 'valid_condition'
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 401
    end
    context 'APIログイン中' do
      include_context 'APIログイン処理'
      it_behaves_like '[APIログイン中]スペースが存在しない'
      it_behaves_like '[APIログイン中]スペースが公開'
      it_behaves_like '[APIログイン中]スペースが非公開'
      it_behaves_like '[APIログイン中]スペースが非公開（削除予約済み）'
    end
    context 'APIログイン中（削除予約済み）' do
      include_context 'APIログイン処理', :destroy_reserved
      include_context 'valid_condition'
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 422, nil, 'alert.user.destroy_reserved'
    end
  end
end
