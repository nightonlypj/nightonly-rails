require 'rails_helper'

RSpec.describe 'SendHistory', type: :request do
  let(:response_json) { JSON.parse(response.body) }
  let(:response_json_send_history) { response_json['send_history'] }

  # GET /send_histories/:space_code/detail/:id(.json) 通知履歴詳細API
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開
  #   権限: ある（管理者〜閲覧者）, ない
  #   通知履歴ID: 存在する, 存在しない
  #     通知対象: 開始確認, 翌営業日・終了確認
  #     送信対象: Slack, メール
  #     翌営業日開始/期限切れ/本日期限/期限内の/本日完了したタスク: ない, 2件（削除済み含む）
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'GET #show' do
    subject { get send_history_path(space_code: space.code, id: send_history.id, format: subject_format), headers: auth_headers.merge(accept_headers) }
    let_it_be(:created_user) { FactoryBot.create(:user) }

    # テスト内容
    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)
        expect(response_json['success']).to eq(true)

        count = expect_send_history_json(response_json_send_history, send_history, member, { detail: true })
        expect(response_json_send_history.count).to eq(count)

        expect(response_json.count).to eq(2)
      end
    end

    # テストケース
    shared_examples_for '通知履歴ID' do
      context '存在する（通知対象が開始確認、送信対象がSlack、翌営業日開始/期限切れ/本日期限/期限内の/本日完了したタスクがない）' do
        include_context 'タスクイベント作成', 0, 0, 0, 0, 0
        let_it_be(:send_history) { FactoryBot.create(:send_history, :start, :slack, send_setting:, target_count: 0) }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context '存在する（通知対象が開始確認、送信対象メール、翌営業日開始/期限切れ/本日期限/期限内の/本日完了したタスクが2件）' do
        include_context 'タスクイベント作成', 0, 1, 1, 1, 1, true # NOTE: 削除済みを追加
        let_it_be(:send_history) do
          FactoryBot.create(:send_history, :start, :email, send_setting:, target_count: 8,
                                                           next_task_event_ids: nil,
                                                           expired_task_event_ids: expired_task_events.pluck(:id).join(','),
                                                           end_today_task_event_ids: end_today_task_events.pluck(:id).join(','),
                                                           date_include_task_event_ids: date_include_task_events.pluck(:id).join(','),
                                                           completed_task_event_ids: completed_task_events.pluck(:id).join(','))
        end
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context '存在する（通知対象が翌営業日・終了確認、送信対象がSlack、翌営業日開始/期限切れ/本日期限/期限内の/本日完了したタスクがない）' do
        include_context 'タスクイベント作成', 0, 0, 0, 0, 0
        let_it_be(:send_history) { FactoryBot.create(:send_history, :next, :slack, send_setting:, target_count: 0) }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context '存在する（通知対象が翌営業日・終了確認、送信対象がメール、翌営業日開始/期限切れ/本日期限/期限内の/本日完了したタスクが2件）' do
        include_context 'タスクイベント作成', 1, 1, 1, 1, 1, true # NOTE: 削除済みを追加
        let_it_be(:send_history) do
          FactoryBot.create(:send_history, :next, :email, send_setting:, target_count: 10,
                                                          next_task_event_ids: next_task_events.pluck(:id).join(','),
                                                          expired_task_event_ids: expired_task_events.pluck(:id).join(','),
                                                          end_today_task_event_ids: end_today_task_events.pluck(:id).join(','),
                                                          date_include_task_event_ids: date_include_task_events.pluck(:id).join(','),
                                                          completed_task_event_ids: completed_task_events.pluck(:id).join(','))
        end
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context '存在しない' do
        let_it_be(:send_history) { FactoryBot.build_stubbed(:send_history) }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToNG(json)', 404
      end
    end

    shared_examples_for '[APIログイン中/削除予約済み][*]権限がある' do |power|
      let_it_be(:member) { FactoryBot.create(:member, power, space:, user:) }
      it_behaves_like '通知履歴ID'
    end
    shared_examples_for '[*][公開]権限がない' do
      let(:member) { nil }
      it_behaves_like '通知履歴ID'
    end
    shared_examples_for '[未ログイン][非公開]権限がない' do
      let_it_be(:send_history) { FactoryBot.create(:send_history, send_setting:, target_count: 0) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 401
    end
    shared_examples_for '[APIログイン中/削除予約済み][非公開]権限がない' do
      let_it_be(:send_history) { FactoryBot.create(:send_history, send_setting:, target_count: 0) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[*]スペースが存在しない' do
      let_it_be(:space) { FactoryBot.build_stubbed(:space) }
      let_it_be(:send_history) { FactoryBot.build_stubbed(:send_history) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 404
    end
    shared_examples_for '[未ログイン]スペースが公開' do
      let_it_be(:space) { FactoryBot.create(:space, :public, created_user:) }
      let_it_be(:send_setting) { FactoryBot.create(:send_setting, :slack, :email, space:) }
      # it_behaves_like '[未ログイン][*]権限がある', :admin # NOTE: 未ログインの為、権限がない
      # it_behaves_like '[未ログイン][*]権限がある', :reader
      it_behaves_like '[*][公開]権限がない'
    end
    shared_examples_for '[APIログイン中/削除予約済み]スペースが公開' do
      let_it_be(:space) { FactoryBot.create(:space, :public, created_user:) }
      let_it_be(:send_setting) { FactoryBot.create(:send_setting, :slack, :email, space:) }
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :admin
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :reader
      it_behaves_like '[*][公開]権限がない'
    end
    shared_examples_for '[未ログイン]スペースが非公開' do
      let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
      let_it_be(:send_setting) { FactoryBot.create(:send_setting, :slack, :email, space:) }
      # it_behaves_like '[未ログイン][*]権限がある', :admin # NOTE: 未ログインの為、権限がない
      # it_behaves_like '[未ログイン][*]権限がある', :reader
      it_behaves_like '[未ログイン][非公開]権限がない'
    end
    shared_examples_for '[APIログイン中/削除予約済み]スペースが非公開' do
      let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
      let_it_be(:send_setting) { FactoryBot.create(:send_setting, :slack, :email, space:) }
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
