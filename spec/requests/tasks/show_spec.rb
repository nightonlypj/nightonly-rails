require 'rails_helper'

RSpec.describe 'Tasks', type: :request do
  let(:response_json) { JSON.parse(response.body) }
  let(:response_json_task) { response_json['task'] }

  # GET /tasks/:space_code/detail/:id(.json) タスク詳細API
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開
  #   権限: ある（管理者, 投稿者, 閲覧者）, ない
  #   タスクID: 存在する, 存在しない
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'GET #show' do
    subject { get task_path(space_code: space.code, id: task.id, format: subject_format), headers: auth_headers.merge(accept_headers) }

    let_it_be(:space_not)     { FactoryBot.build_stubbed(:space) }
    let_it_be(:space_public)  { FactoryBot.create(:space, :public) }
    let_it_be(:space_private) { FactoryBot.create(:space, :private) }

    # テスト内容
    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)
        expect(response_json['success']).to eq(true)

        count = expect_task_json(response_json_task, task, task_cycles, { detail: true, cycles: true })
        expect(response_json_task.count).to eq(count)

        expect(response_json.count).to eq(2)
      end
    end

    # テストケース
    shared_examples_for '[APIログイン中/削除予約済み][*]権限がある' do |power|
      before_all { FactoryBot.create(:member, power, space: space, user: user) }
      context 'タスクIDが存在する' do
        let_it_be(:task) { FactoryBot.create(:task, space: space) }
        let_it_be(:task_cycles) { [FactoryBot.create(:task_cycle, :weekly, task: task, order: 1)] }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context 'タスクIDが存在しない' do
        let_it_be(:task) { FactoryBot.build_stubbed(:task) }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToNG(json)', 404
      end
    end
    shared_examples_for '[*][公開]権限がない' do
      context 'タスクIDが存在する' do
        let_it_be(:task) { FactoryBot.create(:task, space: space) }
        let_it_be(:task_cycles) do
          task_cycle = FactoryBot.create(:task_cycle, :yearly, :week, task: task, order: 3)
          [
            FactoryBot.create(:task_cycle, :monthly, :day, task: task, order: 1),
            FactoryBot.create(:task_cycle, :yearly, :business_day, task: task, order: 2),
            task_cycle # NOTE: 並び順のテストの為、先にcreateする
          ]
        end
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context 'タスクIDが存在しない' do
        let_it_be(:task) { FactoryBot.build_stubbed(:task) }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToNG(json)', 404
      end
    end
    shared_examples_for '[未ログイン][非公開]権限がない' do
      let_it_be(:task) { FactoryBot.create(:task, space: space) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 401
    end
    shared_examples_for '[APIログイン中/削除予約済み][非公開]権限がない' do
      let_it_be(:task) { FactoryBot.create(:task, space: space) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[*]スペースが存在しない' do
      let_it_be(:space) { space_not }
      let_it_be(:task) { FactoryBot.build_stubbed(:task) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 404
    end
    shared_examples_for '[未ログイン]スペースが公開' do
      let_it_be(:space) { space_public }
      # it_behaves_like '[未ログイン][*]権限がある', :admin # NOTE: 未ログインの為、権限がない
      # it_behaves_like '[未ログイン][*]権限がある', :writer
      # it_behaves_like '[未ログイン][*]権限がある', :reader
      it_behaves_like '[*][公開]権限がない'
    end
    shared_examples_for '[APIログイン中/削除予約済み]スペースが公開' do
      let_it_be(:space) { space_public }
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :admin
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :writer
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :reader
      it_behaves_like '[*][公開]権限がない'
    end
    shared_examples_for '[未ログイン]スペースが非公開' do
      let_it_be(:space) { space_private }
      # it_behaves_like '[未ログイン][*]権限がある', :admin # NOTE: 未ログインの為、権限がない
      # it_behaves_like '[未ログイン][*]権限がある', :writer
      # it_behaves_like '[未ログイン][*]権限がある', :reader
      it_behaves_like '[未ログイン][非公開]権限がない'
    end
    shared_examples_for '[APIログイン中/削除予約済み]スペースが非公開' do
      let_it_be(:space) { space_private }
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :admin
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :writer
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :reader
      it_behaves_like '[APIログイン中/削除予約済み][非公開]権限がない'
    end

    shared_examples_for '[APIログイン中/削除予約済み]' do
      it_behaves_like '[*]スペースが存在しない'
      it_behaves_like '[APIログイン中/削除予約済み]スペースが公開'
      it_behaves_like '[APIログイン中/削除予約済み]スペースが非公開'
    end

    context '未ログイン' do
      include_context '未ログイン処理'
      it_behaves_like '[*]スペースが存在しない'
      it_behaves_like '[未ログイン]スペースが公開'
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
