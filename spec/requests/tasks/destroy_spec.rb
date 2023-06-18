require 'rails_helper'

RSpec.describe 'Tasks', type: :request do
  let(:response_json) { JSON.parse(response.body) }

  # POST /tasks/:space_code/delete(.json) タスク削除API(処理)
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開
  #   TODO: 削除予約: ある, ない
  #   権限: ある（管理者）, ない（投稿者, 閲覧者, なし）
  #   パラメータなし, 有効なパラメータ, 無効なパラメータ
  #     IDなし, 存在するIDのみ, 存在しないIDのみ, 存在しないIDも含む
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'POST #destroy' do
    subject { post destroy_task_path(space_code: space.code, format: subject_format), params: params, headers: auth_headers.merge(accept_headers) }
    let_it_be(:space_not)     { FactoryBot.build_stubbed(:space) }
    let_it_be(:space_public)  { FactoryBot.create(:space, :public) }
    let_it_be(:space_private) { FactoryBot.create(:space, :private, created_user: space_public.created_user) }
    let_it_be(:task_nojoin)   { FactoryBot.create(:task) }
    before_all { FactoryBot.create(:task_cycle, task: task_nojoin, order: 1) }

    shared_context 'valid_condition' do
      let_it_be(:space) { space_public }
      let_it_be(:task_destroy) { FactoryBot.create(:task, space: space, created_user: space.created_user) }
      let_it_be(:task_cycles)  { [FactoryBot.create(:task_cycle, task: task_destroy, order: 1)] }
      before_all { FactoryBot.create(:member, space: space, user: user) if user.present? }
      let(:params) { { ids: [task_destroy.id] } }
    end

    # テスト内容
    shared_examples_for 'OK' do
      it 'タスク・周期が削除される' do
        expect { subject }.to change(Task, :count).by(destroy_count * -1) && change(TaskCycle, :count).by(task_cycles.count * -1)
      end
    end
    shared_examples_for 'NG' do
      it 'タスク・周期が削除されない' do
        expect { subject }.to change(Task, :count).by(0) && change(TaskCycle, :count).by(0)
      end
    end

    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)
        expect(response_json['success']).to eq(true)
        expect(response_json['notice']).to eq(get_locale("notice.task.#{notice_key}", count: input_count, destroy_count: destroy_count))
        expect(response_json['count']).to eq(input_count)
        expect(response_json['destroy_count']).to eq(destroy_count)
        expect(response_json.count).to eq(4)
      end
    end

    # テストケース
    shared_examples_for '[APIログイン中][*]権限がある' do |power|
      before_all { FactoryBot.create(:member, power, space: space, user: user) }
      context 'パラメータなし' do
        let(:params) { nil }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'NG(json)'
        it_behaves_like 'ToNG(json)', 422, nil, 'alert.task.destroy.ids.blank'
      end
      context '有効なパラメータ（存在するIDのみ）' do
        let(:params) { { ids: [task_destroy.id] } }
        let(:notice_key)     { 'destroy' }
        let(:input_count)    { 1 }
        let(:destroy_count)  { 1 }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'OK(json)'
        it_behaves_like 'ToOK(json)'
      end
      context '有効なパラメータ（存在しないIDも含む）' do
        let(:params) { { ids: [task_nojoin.id, task_destroy.id] } }
        let(:notice_key)     { 'destroy_include_notfound' }
        let(:input_count)    { 2 }
        let(:destroy_count)  { 1 }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'OK(json)'
        it_behaves_like 'ToOK(json)'
      end
      context '無効なパラメータ（IDなし）' do
        let(:params) { { ids: [] } }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'NG(json)'
        it_behaves_like 'ToNG(json)', 422, nil, 'alert.task.destroy.ids.blank'
      end
      context '無効なパラメータ（存在しないIDのみ）' do
        let(:params) { { ids: [task_nojoin.id] } }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'NG(json)'
        it_behaves_like 'ToNG(json)', 422, nil, 'alert.task.destroy.ids.notfound'
      end
    end
    shared_examples_for '[APIログイン中][*]権限がない' do |power|
      before_all { FactoryBot.create(:member, power, space: space, user: user) if power.present? }
      let(:params) { { ids: [task_destroy.id] } }
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', Settings.api_only_mode ? 406 : 403 # NOTE: HTMLもログイン状態になる
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[APIログイン中]スペースが存在しない' do
      let_it_be(:space) { space_not }
      let(:params) { { ids: [] } }
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', Settings.api_only_mode ? 406 : 404 # NOTE: HTMLもログイン状態になる
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 404
    end
    shared_examples_for '[APIログイン中]スペースが公開' do
      let_it_be(:space) { space_public }
      let_it_be(:task_destroy) { FactoryBot.create(:task, space: space, created_user: space.created_user) }
      let_it_be(:task_cycles)  { [FactoryBot.create(:task_cycle, task: task_destroy, order: 1)] }
      it_behaves_like '[APIログイン中][*]権限がある', :admin
      it_behaves_like '[APIログイン中][*]権限がない', :writer
      it_behaves_like '[APIログイン中][*]権限がない', :reader
      it_behaves_like '[APIログイン中][*]権限がない', nil
    end
    shared_examples_for '[APIログイン中]スペースが非公開' do
      let_it_be(:space) { space_private }
      let_it_be(:task_destroy) { FactoryBot.create(:task, space: space, created_user: space.created_user) }
      let_it_be(:task_cycles)  { [FactoryBot.create(:task_cycle, task: task_destroy, order: 1)] }
      it_behaves_like '[APIログイン中][*]権限がある', :admin
      it_behaves_like '[APIログイン中][*]権限がない', :writer
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
