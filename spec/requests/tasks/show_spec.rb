require 'rails_helper'

RSpec.describe 'Tasks', type: :request do
  let(:response_json) { JSON.parse(response.body) }
  let(:response_json_task) { response_json['task'] }

  # GET /tasks/:space_code/detail/:id(.json) タスク詳細API
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開
  #   権限: ある（管理者〜閲覧者）, ない
  #   タスクID: 存在する, 存在しない
  #   タスク担当者: いない, いる（ユーザーIDs: [管理者]+[投稿者]+閲覧者+未参加+削除予定+削除済み）
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'GET #show' do
    subject { get task_path(space_code: space.code, id: task.id, format: subject_format), headers: auth_headers.merge(accept_headers) }

    let_it_be(:created_user) { FactoryBot.create(:user) }
    let_it_be(:nojoin_user)  { FactoryBot.create(:user) }
    include_context 'メンバーパターン作成(user)'

    shared_context 'タスク担当者作成' do
      before_all do
        user_ids = "#{user_admin.id},#{user_writer.id},#{user_reader.id},#{nojoin_user.id},#{user_destroy_reserved.id},#{user_destroy.id}"
        FactoryBot.create(:task_assigne, task:, user_ids:)
      end
      let(:task_assigne_users) { [user_admin, user_writer] }
    end

    # テスト内容
    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)
        expect(response_json['success']).to be(true)

        count = expect_task_json(response_json_task, task, task_cycles, task_assigne_users, { detail: true, email: member&.power_admin? })
        expect(response_json_task.count).to eq(count)

        expect(response_json.count).to eq(2)
      end
    end

    # テストケース
    shared_examples_for 'タスク担当者' do
      context 'いない' do
        let(:task_assigne_users) { nil }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context 'いる' do
        include_context 'タスク担当者作成'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
    end

    shared_examples_for '[APIログイン中/削除予約済み][*][ある]タスクIDが存在する' do
      let_it_be(:task) { FactoryBot.create(:task, space:, created_user:) }
      let_it_be(:task_cycles) { [FactoryBot.create(:task_cycle, :weekly, task:, order: 1)] }
      it_behaves_like 'タスク担当者'
    end
    shared_examples_for '[*][公開][ない]タスクIDが存在する' do
      let_it_be(:task) { FactoryBot.create(:task, space:, created_user:) }
      let_it_be(:task_cycles) do
        task_cycle = FactoryBot.create(:task_cycle, :yearly, :week, task:, order: 3)
        [
          FactoryBot.create(:task_cycle, :monthly, :day, task:, order: 1),
          FactoryBot.create(:task_cycle, :yearly, :business_day, task:, order: 2),
          task_cycle # NOTE: 並び順のテストの為、先にcreateする
        ]
      end
      it_behaves_like 'タスク担当者'
    end
    shared_examples_for '[*][*][*]タスクIDが存在しない' do
      let_it_be(:task) { FactoryBot.build_stubbed(:task) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 404
    end

    shared_examples_for '[APIログイン中/削除予約済み][*]権限がある' do |power|
      let_it_be(:member) { FactoryBot.create(:member, power, space:, user:) }
      it_behaves_like '[APIログイン中/削除予約済み][*][ある]タスクIDが存在する'
      it_behaves_like '[*][*][*]タスクIDが存在しない'
    end
    shared_examples_for '[*][公開]権限がない' do
      let(:member) { nil }
      it_behaves_like '[*][公開][ない]タスクIDが存在する'
      it_behaves_like '[*][*][*]タスクIDが存在しない'
    end
    shared_examples_for '[未ログイン][非公開]権限がない' do
      let_it_be(:task) { FactoryBot.create(:task, space:, created_user:) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 401
    end
    shared_examples_for '[APIログイン中/削除予約済み][非公開]権限がない' do
      let_it_be(:task) { FactoryBot.create(:task, space:, created_user:) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[*]スペースが存在しない' do
      let_it_be(:space) { FactoryBot.build_stubbed(:space) }
      let_it_be(:task) { FactoryBot.build_stubbed(:task) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 404
    end
    shared_examples_for '[未ログイン]スペースが公開' do
      let_it_be(:space) { FactoryBot.create(:space, :public, created_user:) }
      include_context 'メンバーパターン作成(member)'
      # it_behaves_like '[未ログイン][*]権限がある', :admin # NOTE: 未ログインの為、権限がない
      # it_behaves_like '[未ログイン][*]権限がある', :reader
      it_behaves_like '[*][公開]権限がない'
    end
    shared_examples_for '[APIログイン中/削除予約済み]スペースが公開' do
      let_it_be(:space) { FactoryBot.create(:space, :public, created_user:) }
      include_context 'メンバーパターン作成(member)'
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :admin
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :reader
      it_behaves_like '[*][公開]権限がない'
    end
    shared_examples_for '[未ログイン]スペースが非公開' do
      let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
      include_context 'メンバーパターン作成(member)'
      # it_behaves_like '[未ログイン][*]権限がある', :admin # NOTE: 未ログインの為、権限がない
      # it_behaves_like '[未ログイン][*]権限がある', :reader
      it_behaves_like '[未ログイン][非公開]権限がない'
    end
    shared_examples_for '[APIログイン中/削除予約済み]スペースが非公開' do
      let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
      include_context 'メンバーパターン作成(member)'
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :admin
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
