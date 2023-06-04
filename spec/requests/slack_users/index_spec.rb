require 'rails_helper'

RSpec.describe 'SlackUser', type: :request do
  let(:response_json) { JSON.parse(response.body) }
  let(:response_json_slack_users) { response_json['slack_users'] }

  # GET /slack_users(.json) Slackユーザー情報一覧API
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   参加スペース: ない, ある
  #   通知設定: 1件もない, メールのみ, Slackのみ（論理削除）, Slack＆メール＋Slackのみ
  #     Slackユーザー: ない, ある, SlackメンバーIDが空
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'GET #index' do
    subject { get slack_users_path(format: subject_format), headers: auth_headers.merge(accept_headers) }
    let_it_be(:spaces) { FactoryBot.create_list(:space, 3) }
    let_it_be(:slack_domains) { FactoryBot.create_list(:slack_domain, 3) }
    let_it_be(:other_user) { FactoryBot.create(:user) }
    before_all { spaces.each { |space| FactoryBot.create(:member, space: space, user: other_user) } }

    # テスト内容
    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)
        expect(response_json['success']).to eq(true)

        expect(response_json_slack_users.count).to eq(except_memberids.count)
        response_json_slack_users.each { |data| expect(data['memberid']).to eq(except_memberids[data['name']]) }

        expect(response_json.count).to eq(2)
      end
    end

    # テストケース
    shared_examples_for '[APIログイン中/削除予約済み]' do
      context '参加スペースがない' do
        let(:except_memberids) { {} }
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)'
      end
      context '参加スペースがある' do
        before_all { spaces.each { |space| FactoryBot.create(:member, space: space, user: user) } }
        context '通知設定が1件もない' do
          let(:except_memberids) { {} }
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'ToOK(json)'
        end
        context '通知設定がメールのみ' do
          before_all { FactoryBot.create(:send_setting, :email, space: spaces[0]) }
          let(:except_memberids) { {} }
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'ToOK(json)'
        end
        context '通知設定がSlackのみ（論理削除）' do
          before_all { FactoryBot.create(:send_setting, :slack, :deleted, space: spaces[0], slack_domain: slack_domains[0]) }
          let(:except_memberids) { {} }
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'ToOK(json)'
        end
        context '通知設定がSlack＆メール＋Slackのみ（Slackユーザー: ない, ある, SlackメンバーIDが空）' do
          let_it_be(:send_settings) do
            [
              FactoryBot.create(:send_setting, :slack, :email, space: spaces[0], slack_domain: slack_domains[0]),
              FactoryBot.create(:send_setting, :slack, space: spaces[1], slack_domain: slack_domains[1]),
              FactoryBot.create(:send_setting, :slack, space: spaces[2], slack_domain: slack_domains[2])
            ]
          end
          let_it_be(:except_memberids) do
            slack_user1 = FactoryBot.create(:slack_user, slack_domain: send_settings[1].slack_domain, user: user)
            FactoryBot.create(:slack_user, slack_domain: send_settings[2].slack_domain, user: user, memberid: '')
            {
              slack_domains[0].name => nil,
              slack_domains[1].name => slack_user1.memberid,
              slack_domains[2].name => ''
            }
          end
          before_all { send_settings.each { |send_setting| FactoryBot.create(:slack_user, slack_domain: send_setting.slack_domain, user: other_user) } }
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'ToOK(json)'
        end
      end
    end

    context '未ログイン' do
      include_context '未ログイン処理'
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 401
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
