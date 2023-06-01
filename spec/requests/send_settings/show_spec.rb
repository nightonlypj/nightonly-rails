require 'rails_helper'

RSpec.describe 'SendSetting', type: :request do
  let(:response_json) { JSON.parse(response.body) }
  let(:response_json_send_setting)       { response_json['send_setting'] }
  let(:response_json_current_slack_user) { response_json['current_slack_user'] }

  # GET /send_settings/:space_code/detail(.json) 通知設定詳細API
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開
  #   権限: ある（管理者〜閲覧者）, ない
  #   通知設定: 存在しない, 存在する（1件, 2件）
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'GET #show' do
    subject { get send_setting_path(space_code: space.code, format: subject_format), headers: auth_headers.merge(accept_headers) }

    let_it_be(:space_not)     { FactoryBot.build_stubbed(:space) }
    let_it_be(:space_public)  { FactoryBot.create(:space, :public) }
    let_it_be(:space_private) { FactoryBot.create(:space, :private) }
    let_it_be(:last_updated_user) { FactoryBot.create(:user) }
    let_it_be(:destroy_user)      { FactoryBot.build_stubbed(:user) }

    # テスト内容
    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)

        result = 2
        expect(response_json['success']).to eq(true)

        count = expect_send_setting_json(response_json_send_setting, send_setting, member)
        expect(response_json_send_setting.count).to eq(count)

        if slack_user.present?
          expect(response_json_current_slack_user['memberid']).to eq(slack_user.memberid)
          expect(response_json_current_slack_user.count).to eq(1)
          result += 1
        end
        expect(response_json.count).to eq(result)
      end
    end

    # テストケース
    shared_examples_for '通知設定' do
      context '通知設定が存在しない' do
        let(:slack_user) { nil }
        let(:send_setting) { nil }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context '通知設定が存在する（1件）' do
        let(:slack_user) { nil }
        let_it_be(:send_setting) { FactoryBot.create(:send_setting, :changed, :slack, :email, space: space, last_updated_user: last_updated_user) }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context '通知設定が存在する（2件）' do
        before_all { FactoryBot.create(:send_setting, :changed, :slack, :email, space: space) }
        let_it_be(:slack_domain) { FactoryBot.create(:slack_domain) }
        let_it_be(:slack_user)   { FactoryBot.create(:slack_user, slack_domain: slack_domain, user: user) if user.present? }
        let_it_be(:send_setting) { FactoryBot.create(:send_setting, space: space, slack_domain: slack_domain, last_updated_user_id: destroy_user.id) }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
    end

    shared_examples_for '[APIログイン中/削除予約済み][*]権限がある' do |power|
      let_it_be(:member) { FactoryBot.create(:member, power, space: space, user: user) }
      it_behaves_like '通知設定'
    end
    shared_examples_for '[*][公開]権限がない' do
      let(:member) { nil }
      it_behaves_like '通知設定'
    end
    shared_examples_for '[未ログイン][非公開]権限がない' do
      let(:member) { nil }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 401
    end
    shared_examples_for '[APIログイン中/削除予約済み][非公開]権限がない' do
      let(:member) { nil }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[*]スペースが存在しない' do
      let_it_be(:space) { space_not }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 404
    end
    shared_examples_for '[未ログイン]スペースが公開' do
      let_it_be(:space) { space_public }
      # it_behaves_like '[未ログイン][*]権限がある', :admin # NOTE: 未ログインの為、権限がない
      # it_behaves_like '[未ログイン][*]権限がある', :reader
      it_behaves_like '[*][公開]権限がない'
    end
    shared_examples_for '[APIログイン中/削除予約済み]スペースが公開' do
      let_it_be(:space) { space_public }
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :admin
      it_behaves_like '[APIログイン中/削除予約済み][*]権限がある', :reader
      it_behaves_like '[*][公開]権限がない'
    end
    shared_examples_for '[未ログイン]スペースが非公開' do
      let_it_be(:space) { space_private }
      # it_behaves_like '[未ログイン][*]権限がある', :admin # NOTE: 未ログインの為、権限がない
      # it_behaves_like '[未ログイン][*]権限がある', :reader
      it_behaves_like '[未ログイン][非公開]権限がない'
    end
    shared_examples_for '[APIログイン中/削除予約済み]スペースが非公開' do
      let_it_be(:space) { space_private }
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
