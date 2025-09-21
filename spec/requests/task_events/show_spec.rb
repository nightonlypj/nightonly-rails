require 'rails_helper'

RSpec.describe 'TaskEvents', type: :request do
  let(:response_json) { response.parsed_body }
  let(:response_json_task)          { response_json['task'] }
  let(:response_json_event)         { response_json['event'] }
  let(:response_json_deleted_cycle) { response_json['deleted_cycle'] }

  # GET /task_events/:space_code/detail/:code(.json) タスクイベント詳細API
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開
  #   権限: ある（管理者〜閲覧者）, ない
  #   イベントコード: 存在する, 存在しない
  #     ステータス: 未完了（未処理）, 完了
  #     初期/担当者: いない, いる, アカウント削除済み
  #     最終更新者: いない, いる, アカウント削除済み
  #     タスク担当者: いない, いる（ユーザーIDs: [管理者]+[投稿者]+閲覧者+未参加+削除予定+削除済み）
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'GET #show' do
    subject { get task_event_path(space_code: space.code, code: task_event.code, format: subject_format), headers: auth_headers.merge(accept_headers) }

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

        count = expect_task_event_json(response_json_event, task, task_event.task_cycle, task_event, nil, { detail: true, email: member&.power_admin? })
        expect(response_json_event.count).to eq(count)

        result = 3
        if task_cycle_deleted.present?
          count = expect_task_cycle_json(response_json_deleted_cycle, task_cycle_deleted)
          expect(response_json_deleted_cycle.count).to eq(count)
          result += 1
        else
          expect(response_json_deleted_cycle).to be_nil
        end

        expect(response_json.count).to eq(result)
      end
    end

    # テストケース
    shared_examples_for '[APIログイン中/削除予約済み][*]権限がある' do |power|
      let_it_be(:member) { FactoryBot.create(:member, power, space:, user:) }
      let_it_be(:task) { FactoryBot.create(:task, space:, created_user:) }
      let_it_be(:task_cycle_deleted) { nil }
      let_it_be(:task_cycles) { [FactoryBot.create(:task_cycle, :weekly, task:, order: 1)] }
      context 'イベントコードが存在する（ステータスが未完了（未処理）、初期/担当者・最終更新者がいない、タスク担当者がいない）' do
        let_it_be(:task_event) do
          FactoryBot.create(:task_event, :untreated, task_cycle: task_cycles[0], init_assigned_user: nil, assigned_user: nil, last_updated_user: nil)
        end
        let(:task_assigne_users) { nil }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context 'イベントコードが存在しない' do
        let_it_be(:task_event) { FactoryBot.build_stubbed(:task_event) }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToNG(json)', 404
      end
    end
    shared_examples_for '[*][公開]権限がない' do
      let(:member) { nil }
      let_it_be(:task) { FactoryBot.create(:task, :active, space:, created_user:) }
      let_it_be(:task_cycle_deleted) { FactoryBot.create(:task_cycle, :yearly, :week, :deleted, task:, order: nil) }
      let_it_be(:task_cycles) do
        [
          FactoryBot.create(:task_cycle, :monthly, :day, task:, order: 1),
          FactoryBot.create(:task_cycle, :yearly, :business_day, task:, order: 2)
        ]
      end
      context 'イベントコードが存在する（ステータスが完了、初期/担当者・最終更新者がいる、タスク担当者がいる）' do
        let_it_be(:task_event) do
          FactoryBot.create(:task_event, :completed, :assigned, task_cycle: task_cycle_deleted, init_assigned_user: user_destroy_reserved,
                                                                assigned_user: user_writer, last_updated_user: user_admin)
        end
        include_context 'タスク担当者作成'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context 'イベントコードが存在する（初期/担当者・最終更新者がアカウント削除済み、タスク担当者がいる）' do
        let_it_be(:task_event) do
          FactoryBot.create(:task_event, :assigned, task_cycle: task_cycle_deleted, init_assigned_user_id: user_destroy.id,
                                                    assigned_user_id: user_destroy.id, last_updated_user_id: user_destroy.id)
        end
        include_context 'タスク担当者作成'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context 'イベントコードが存在しない' do
        let_it_be(:task_event) { FactoryBot.build_stubbed(:task_event) }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToNG(json)', 404
      end
    end
    shared_examples_for '[未ログイン][非公開]権限がない' do
      let_it_be(:task_event) { FactoryBot.create(:task_event, space:) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 401
    end
    shared_examples_for '[APIログイン中/削除予約済み][非公開]権限がない' do
      let_it_be(:task_event) { FactoryBot.create(:task_event, space:) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[*]スペースが存在しない' do
      let_it_be(:space) { FactoryBot.build_stubbed(:space) }
      let_it_be(:task_event) { FactoryBot.build_stubbed(:task_event) }
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
