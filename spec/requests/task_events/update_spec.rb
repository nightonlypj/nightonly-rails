require 'rails_helper'

RSpec.describe 'TaskEvents', type: :request do
  let(:response_json) { JSON.parse(response.body) }
  let(:response_json_event) { response_json['event'] }

  # POST /task_events/:space_code/update/:code(.json) タスクイベント変更API(処理)
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開
  #   TODO: 削除予約: ある, ない
  #   権限: ある（管理者, 投稿者）, ない（閲覧者, なし）
  #   イベントコード: 存在する, 存在しない
  #   パラメータなし, 有効なパラメータ（通知/非通知ステータス変更なし, 通知→非通知/非通知→通知ステータス, 担当なし/自分→担当なし/自分）, 無効なパラメータ
  #     detailパラメータ: ない, true, false
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'POST #update' do
    subject { post update_task_event_path(space_code: space.code, code: task_event.code, format: subject_format), params: params, headers: auth_headers.merge(accept_headers) }

    let(:valid_attributes) { { last_ended_date: Time.current.to_date, status: :untreated, memo: nil } }
    let(:invalid_attributes) { valid_attributes.merge(status: nil) }
    let(:current_task_event) { TaskEvent.last }

    let_it_be(:space_not)     { FactoryBot.build_stubbed(:space) }
    let_it_be(:space_public)  { FactoryBot.create(:space, :public) }
    let_it_be(:space_private) { FactoryBot.create(:space, :private) }
    shared_context 'valid_condition' do
      let(:params) { { task_event: valid_attributes } }
      let_it_be(:space) { space_private }
      include_context 'set_member_power', :admin
      let_it_be(:task_event) { FactoryBot.create(:task_event, space: space) }
    end

    # テスト内容
    shared_examples_for 'OK' do
      let!(:start_time) { Time.current.floor }
      it '対象項目が変更される' do
        subject
        expect(current_task_event.code).to eq(task_event.code)
        expect(current_task_event.space).to eq(space)
        expect(current_task_event.task_cycle).to eq(task_event.task_cycle)
        expect(current_task_event.started_date).to eq(task_event.started_date)
        expect(current_task_event.ended_date).to eq(task_event.ended_date)
        expect(current_task_event.last_ended_date).to eq(attributes[:last_ended_date])
        expect(current_task_event.last_completed_at).to expect_last_completed_at[:new] ? be_between(start_time, Time.current) : eq(expect_last_completed_at[:data])
        expect(current_task_event.status.to_sym).to eq(attributes[:status])
        expect(current_task_event.assigned_user_id).to eq(expect_assigned_user_id)
        expect(current_task_event.assigned_at).to expect_assigned_at[:new] ? be_between(start_time, Time.current) : eq(expect_assigned_at[:data])
        expect(current_task_event.memo).to eq(attributes[:memo])
        expect(current_task_event.last_updated_user_id).to be(user.id)
      end
    end
    shared_examples_for 'NG' do
      it '変更されない' do
        subject
        expect(current_task_event).to eq(task_event)
      end
    end

    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)
        result = 3
        expect(response_json['success']).to eq(true)
        expect(response_json['notice']).to eq(get_locale('notice.task_event.update'))

        count = expect_task_event_json(response_json_event, task_event.task_cycle.task, task_event.task_cycle, current_task_event, nil, { detail: params[:detail] })
        expect(response_json_event.count).to eq(count)

        expect(response_json.count).to eq(result)
      end
    end

    # テストケース
    shared_examples_for '[APIログイン中][*]権限がある' do |power|
      include_context 'set_member_power', power
      context 'イベントコードが存在する' do
        context 'パラメータなし' do
          let_it_be(:task_event) { FactoryBot.create(:task_event, space: space) }
          let(:params) { nil }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'NG(json)'
          it_behaves_like 'ToNG(json)', 422, { last_ended_date: [get_locale('activerecord.errors.models.task_event.attributes.last_ended_date.blank')] }
        end
        context '有効なパラメータ（通知ステータス変更なし、担当なし→自分）, detailパラメータがない' do # 未処理 -> 処理中
          let_it_be(:task_event) { FactoryBot.create(:task_event, space: space, status: :untreated, assigned_user: nil) }
          let(:attributes) { valid_attributes.merge(status: :processing, assign_myself: true) }
          let(:params) { { task_event: attributes } }
          let(:expect_last_completed_at) { { data: nil } }
          let(:expect_assigned_user_id) { user.id }
          let(:expect_assigned_at) { { new: true } }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'OK(json)'
          it_behaves_like 'ToOK(json)'
        end
        context '有効なパラメータ（非通知ステータス変更なし、自分→担当なし）, detailパラメータがtrue' do # 完了 -> 対応不要
          let_it_be(:task_event) { FactoryBot.create(:task_event, :completed, space: space, assigned_user: user) }
          let(:attributes) { valid_attributes.merge(status: :unnecessary, assign_delete: true) }
          let(:params) { { task_event: attributes, detail: true } }
          let(:expect_last_completed_at) { { data: task_event.last_completed_at } }
          let(:expect_assigned_user_id) { nil }
          let(:expect_assigned_at) { { data: nil } }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'OK(json)'
          it_behaves_like 'ToOK(json)'
        end
        context '有効なパラメータ（通知→非通知ステータス、自分→自分）, detailパラメータがtrue' do # 処理中 -> 完了
          let_it_be(:task_event) { FactoryBot.create(:task_event, space: space, status: :processing, assigned_user: user) }
          let(:attributes) { valid_attributes.merge(status: :complete) }
          let(:params) { { task_event: attributes, detail: true } }
          let(:expect_last_completed_at) { { new: true } }
          let(:expect_assigned_user_id) { user.id }
          let(:expect_assigned_at) { { data: task_event.assigned_at } }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'OK(json)'
          it_behaves_like 'ToOK(json)'
        end
        context '有効なパラメータ（非通知→通知ステータス、担当なし→担当なし）, detailパラメータがfalse' do # 完了 -> 確認待ち
          let_it_be(:task_event) { FactoryBot.create(:task_event, :completed, space: space, assigned_user: nil) }
          let(:attributes) { valid_attributes.merge(status: :waiting_confirm) }
          let(:params) { { task_event: attributes, detail: false } }
          let(:expect_last_completed_at) { { data: nil } }
          let(:expect_assigned_user_id) { nil }
          let(:expect_assigned_at) { { data: nil } }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'OK(json)'
          it_behaves_like 'ToOK(json)'
        end
        context '無効なパラメータ' do
          let_it_be(:task_event) { FactoryBot.create(:task_event, space: space) }
          let(:params) { { task_event: invalid_attributes } }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'NG(json)'
          it_behaves_like 'ToNG(json)', 422, { status: [get_locale('activerecord.errors.models.task_event.attributes.status.blank')] }
        end
      end
      context 'イベントコードが存在しない' do
        let_it_be(:task_event) { FactoryBot.build_stubbed(:task_event) }
        let(:params) { { task_event: valid_attributes } }
        # it_behaves_like 'NG(html)' # NOTE: 存在しない為
        it_behaves_like 'ToNG(html)', 406
        # it_behaves_like 'NG(json)'
        it_behaves_like 'ToNG(json)', 404
      end
    end
    shared_examples_for '[APIログイン中][*]権限がない' do |power|
      include_context 'set_member_power', power
      let_it_be(:task_event) { FactoryBot.create(:task_event, space: space) }
      let(:params) { { task_event: valid_attributes } }
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[APIログイン中][*]' do
      it_behaves_like '[APIログイン中][*]権限がある', :admin
      it_behaves_like '[APIログイン中][*]権限がある', :writer
      it_behaves_like '[APIログイン中][*]権限がない', :reader
      it_behaves_like '[APIログイン中][*]権限がない', nil
    end

    shared_examples_for '[APIログイン中]スペースが存在しない' do
      let_it_be(:space) { space_not }
      let_it_be(:task_event) { FactoryBot.build_stubbed(:task_event) }
      let(:params) { { task_event: valid_attributes } }
      # it_behaves_like 'NG(html)' # NOTE: 存在しない為
      it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
      # it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 404
    end
    shared_examples_for '[APIログイン中]スペースが公開' do
      let_it_be(:space) { space_public }
      it_behaves_like '[APIログイン中][*]'
    end
    shared_examples_for '[APIログイン中]スペースが非公開' do
      let_it_be(:space) { space_private }
      it_behaves_like '[APIログイン中][*]'
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
