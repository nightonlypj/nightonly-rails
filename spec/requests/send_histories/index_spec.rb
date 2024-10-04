require 'rails_helper'

RSpec.describe 'SendHistory', type: :request do
  let(:response_json) { JSON.parse(response.body) }
  let(:response_json_send_history)   { response_json['send_history'] }
  let(:response_json_send_histories) { response_json['send_histories'] }

  # GET /send_histories/:space_code(.json) 通知履歴一覧API
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開
  #   権限: ある（管理者〜閲覧者）, ない
  #   通知履歴: ない, 最大表示数と同じ, 最大表示数より多い
  #     通知対象: 開始確認, 翌営業日・終了確認
  #     送信対象: Slack, メール
  #     ステータス: 処理待ち, 処理中, 成功, スキップ, 失敗
  #     作成者: いる, アカウント削除済み
  #     最終更新者: いない, いる, アカウント削除済み
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'GET #index' do
    subject { get send_histories_path(space_code: space.code, page: subject_page, format: subject_format), headers: auth_headers.merge(accept_headers) }

    let_it_be(:created_user) { FactoryBot.create(:user) }
    let_it_be(:other_send_setting) { FactoryBot.create(:send_setting) }

    # テスト内容
    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)
        expect(response_json['success']).to be(true)

        expect(response_json_send_history['total_count']).to eq(send_histories.count)
        expect(response_json_send_history['current_page']).to eq(subject_page)
        expect(response_json_send_history['total_pages']).to eq((send_histories.count - 1).div(Settings.default_send_histories_limit) + 1)
        expect(response_json_send_history['limit_value']).to eq(Settings.default_send_histories_limit)
        expect(response_json_send_history.count).to eq(4)

        expect(response_json.count).to eq(3)
      end
    end

    shared_examples_for 'リスト表示(json)' do |page|
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      let(:subject_page) { page }
      let(:start_no)     { (Settings.default_send_histories_limit * (page - 1)) + 1 }
      let(:end_no)       { [send_histories.count, Settings.default_send_histories_limit * page].min }
      it '件数・対象項目が一致する' do
        subject
        expect(response_json_send_histories.count).to eq(end_no - start_no + 1)
        (start_no..end_no).each do |no|
          data = response_json_send_histories[no - start_no]
          send_history = send_histories[send_histories.count - no]
          count = expect_send_history_json(data, send_history, member, { detail: false })
          expect(data.count).to eq(count)
        end
      end
    end

    # テストケース
    shared_examples_for '通知履歴' do
      context 'ない' do
        include_context '通知履歴一覧作成', 0, 0, 0, 0, 0
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)', 1
        it_behaves_like 'リスト表示(json)', 1
      end
      context '最大表示数と同じ' do
        count = Settings.test_send_histories_count
        include_context '通知履歴一覧作成', count.waiting, count.processing, count.success, count.skip, count.failure
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)', 1
        it_behaves_like 'リスト表示(json)', 1
      end
      context '最大表示数より多い' do
        count = Settings.test_send_histories_count
        include_context '通知履歴一覧作成', count.waiting, count.processing, count.success, count.skip, count.failure + 1
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)', 1
        it_behaves_like 'ToOK(json)', 2
        it_behaves_like 'リスト表示(json)', 1
        it_behaves_like 'リスト表示(json)', 2
      end
    end

    shared_examples_for '[APIログイン中/削除予約済み][非公開]権限がある' do |power|
      let_it_be(:member) { FactoryBot.create(:member, power, space:, user:) }
      it_behaves_like '通知履歴'
    end
    shared_examples_for '[APIログイン中/削除予約済み][非公開]権限がない' do
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[*]スペースが存在しない' do
      let_it_be(:space) { FactoryBot.build_stubbed(:space) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 404
    end
    shared_examples_for '[*]スペースが公開' do
      let_it_be(:space) { FactoryBot.create(:space, :public, created_user:) }
      include_context '通知設定作成'
      let(:member) { nil }
      it_behaves_like '通知履歴'
    end
    shared_examples_for '[未ログイン]スペースが非公開' do
      let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 401
    end
    shared_examples_for '[APIログイン中/削除予約済み]スペースが非公開' do
      let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
      include_context '通知設定作成'
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
