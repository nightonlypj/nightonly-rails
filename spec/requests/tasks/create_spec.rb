require 'rails_helper'

RSpec.describe 'Tasks', type: :request do
  let(:response_json) { JSON.parse(response.body) }
  let(:response_json_task)   { response_json['task'] }
  let(:response_json_events) { response_json['events'] }

  # POST /tasks/:space_code/create(.json) タスク追加API(処理)
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開
  #   TODO: 削除予約: ある, ない
  #   権限: ある（管理者, 投稿者）, ない（閲覧者, なし）
  #   パラメータなし, 有効なパラメータ, 無効なパラメータ
  #     タスク: 正常値, 不正値
  #     周期: 毎週 × 削除なし/あり, 毎月/毎年 × 日/営業日/週, ない, 不正値, 文字, 曜日/日/営業日が重複, 最大数より多い
  #     monthsパラメータ: ない, ある, 空, 不正値
  #     detailパラメータ: ない, true, false
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'POST #create' do
    subject do
      travel_to current_date do
        post create_task_path(space_code: space.code, format: subject_format), params: params, headers: auth_headers.merge(accept_headers)
      end
    end

    include_context '[task]作成・更新条件'
    let_it_be(:valid_task_attributes)  { FactoryBot.attributes_for(:task, started_date: current_date, ended_date: nil) }
    let_it_be(:valid_cycle_attributes) { FactoryBot.attributes_for(:task_cycle).reject { |key| key == :order } }
    let_it_be(:valid_attributes)         { valid_task_attributes.merge(cycles: [valid_cycle_attributes]) }
    let_it_be(:invalid_task_attributes)  { valid_task_attributes.merge(title: nil) }
    let_it_be(:invalid_cycle_attributes) { valid_cycle_attributes.merge(cycle: nil) }
    let(:current_task)               { Task.eager_load(:task_cycles_active).last }
    let(:current_task_cycles_active) { current_task.task_cycles_active.order(:order, :updated_at, :id) }

    let_it_be(:space_not)     { FactoryBot.build_stubbed(:space) }
    let_it_be(:space_public)  { FactoryBot.create(:space, :public) }
    let_it_be(:space_private) { FactoryBot.create(:space, :private) }
    shared_context 'valid_condition' do
      let(:params) { { task: valid_attributes } }
      let_it_be(:space) { space_private }
      include_context 'set_member_power', :admin
    end

    # テスト内容
    shared_examples_for 'OK' do
      it 'タスクが1件・周期が対象数作成・対象項目が設定される' do
        expect do
          subject
          expect(current_task.space).to eq(space)
          expect(current_task.priority.to_sym).to eq(attributes[:priority])
          expect(current_task.title).to eq(attributes[:title])
          expect(current_task.summary).to eq(attributes[:summary])
          expect(current_task.premise).to eq(attributes[:premise])
          expect(current_task.process).to eq(attributes[:process])
          expect(current_task.started_date).to eq(attributes[:started_date])
          expect(current_task.ended_date).to eq(attributes[:ended_date])
          expect(current_task.created_user_id).to be(user.id)
          expect(current_task.last_updated_user).to be_nil

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
            expect(current_task_cycle.order).to eq(index + 1)
            expect(current_task_cycle.deleted_at).to be_nil
          end

          expect(current_task.task_cycles_inactive.count).to eq(0)
        end.to change(Task, :count).by(1) && change(TaskCycle, :count).by(expect_task_cycles_active.count)
      end
    end
    shared_examples_for 'NG' do
      it 'タスク・周期が作成されない' do
        expect { subject }.to change(Task, :count).by(0) && change(TaskCycle, :count).by(0)
      end
    end

    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      let(:task_count) { 1 }
      it 'HTTPステータスが201。対象項目が一致する' do
        is_expected.to eq(201)
        result = 3
        expect(response_json['success']).to eq(true)
        expect(response_json['notice']).to eq(get_locale('notice.task.create'))
        if use_events
          expect(response_json_events.count).to eq(expect_events.count)
          response_json_events.each_with_index do |response_json_event, index|
            current_task_cycle = current_task_cycles_active[expect_events[index][:index]]
            count = expect_task_event_json(response_json_event, current_task, current_task_cycle, nil, expect_events[index], { detail: false })
            expect(response_json_event.count).to eq(count)
          end
          result += 1
        else
          expect(response_json_events).to be_nil
        end

        count = expect_task_json(response_json_task, current_task, current_task_cycles_active, { detail: params[:detail], cycles: !use_events })
        expect(response_json_task.count).to eq(count)

        expect(response_json.count).to eq(result)
      end
    end

    # テストケース
    shared_examples_for '[APIログイン中][*]権限がある' do |power|
      include_context 'set_member_power', power
      it_behaves_like '[task]パラメータなし'
      it_behaves_like '[task]有効なパラメータ'
      it_behaves_like '[task]無効なパラメータ'
    end
    shared_examples_for '[APIログイン中][*]権限がない' do |power|
      include_context 'set_member_power', power
      let(:params) { { task: valid_attributes } }
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[APIログイン中]スペースが存在しない' do
      let_it_be(:space) { space_not }
      let(:params) { { task: valid_attributes } }
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 404
    end
    shared_examples_for '[APIログイン中]スペースが公開' do
      let_it_be(:space) { space_public }
      it_behaves_like '[APIログイン中][*]権限がある', :admin
      it_behaves_like '[APIログイン中][*]権限がある', :writer
      it_behaves_like '[APIログイン中][*]権限がない', :reader
      it_behaves_like '[APIログイン中][*]権限がない', nil
    end
    shared_examples_for '[APIログイン中]スペースが非公開' do
      let_it_be(:space) { space_private }
      it_behaves_like '[APIログイン中][*]権限がある', :admin
      it_behaves_like '[APIログイン中][*]権限がある', :writer
      it_behaves_like '[APIログイン中][*]権限がない', :reader
      it_behaves_like '[APIログイン中][*]権限がない', nil
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
