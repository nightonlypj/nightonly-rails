require 'rails_helper'

RSpec.describe 'SlackUser', type: :request do
  let(:response_json) { JSON.parse(response.body) }
  let(:response_json_slack_users) { response_json['slack_users'] }

  # POST /slack_users/update(.json) Slackユーザー情報変更API(処理)
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   パラメータなし, 有効なパラメータ, 無効なパラメータ
  #     Slackドメイン名: ない, 存在しない, 参加, 未参加
  #     SlackメンバーID: ない, 最小文字数より少ない, 最小文字数と同じ, 最大文字数と同じ, 最大文字数より多い, 不正値
  #     Slackメンバー: 存在しない, 存在する
  #     1件, 2件
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'POST #update' do
    subject { post update_slack_user_path(format: subject_format), params:, headers: auth_headers.merge(accept_headers) }
    let_it_be(:spaces) { FactoryBot.create_list(:space, 3) }
    let_it_be(:slack_domains) { FactoryBot.create_list(:slack_domain, 3) }
    let_it_be(:send_settings) do
      [
        FactoryBot.create(:send_setting, :slack, :email, space: spaces[0], slack_domain: slack_domains[0]),
        FactoryBot.create(:send_setting, :slack, space: spaces[1], slack_domain: slack_domains[1])
      ]
    end
    let_it_be(:other_send_setting) { FactoryBot.create(:send_setting, :slack, slack_domain: slack_domains[2]) }
    let_it_be(:valid_memberid) { Faker::Number.hexadecimal(digits: Settings.slack_user_memberid_minimum).upcase }
    let(:current_slack_users) { SlackUser.where(user:).eager_load(:slack_domain).order(:id) }

    # テスト内容
    shared_examples_for 'OK' do
      it '対象項目が変更される' do
        subject
        expect(current_slack_users.count).to eq(expect_slack_users.count)
        current_slack_users.each { |current_slack_user| expect(current_slack_user.memberid).to eq(expect_slack_users[current_slack_user.slack_domain.name]) }
      end
    end
    shared_examples_for 'NG' do
      it '変更されない' do
        subject
        expect(current_slack_users.count).to eq(slack_user.present? ? 1 : 0)
        expect(current_slack_users.first).to eq(slack_user) if slack_user.present?
      end
    end

    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)
        expect(response_json['success']).to eq(true)
        expect(response_json['notice']).to eq(get_locale('notice.slack_user.update'))

        expect(response_json_slack_users.count).to eq(except_memberids.count)
        response_json_slack_users.each { |data| expect(data['memberid']).to eq(except_memberids[data['name']]) }

        expect(response_json.count).to eq(3)
      end
    end

    # テストケース
    context '未ログイン' do
      include_context '未ログイン処理'
      let(:slack_user) { nil }
      let(:params) { nil }
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 401
    end
    context 'APIログイン中' do
      include_context 'APIログイン処理'
      context 'パラメータなし' do
        let(:slack_user) { nil }
        let(:params) { nil }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'NG(json)'
        it_behaves_like 'ToNG(json)', 422, {
          name1: [get_locale('errors.messages.param.blank')],
          memberid1: [get_locale('activerecord.errors.models.slack_user.attributes.memberid.blank')]
        }
      end
      context do
        before_all { spaces.each { |space| FactoryBot.create(:member, space:, user:) } }
        context '有効なパラメータ（SlackメンバーIDがない、Slackメンバーに存在しない、1件）' do # 未設定時のお知らせ表示を消すのに利用
          let(:slack_user) { nil }
          let(:params) { { slack_users: [{ name: slack_domains[0].name, memberid: nil }] } }
          let(:expect_slack_users) { { slack_domains[0].name => nil } }
          let(:except_memberids) { expect_slack_users.merge(slack_domains[1].name => nil) }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'OK(json)'
          it_behaves_like 'ToOK(json)'
        end
        context '有効なパラメータ（SlackメンバーIDが最小文字数と同じ、Slackメンバーに存在する、1件）' do
          let_it_be(:before_memberid) { 'A' * Settings.slack_user_memberid_minimum }
          let_it_be(:after_memberid)  { 'B' * Settings.slack_user_memberid_minimum }
          let_it_be(:slack_user) { FactoryBot.create(:slack_user, slack_domain: slack_domains[0], user:, memberid: before_memberid) }
          let(:params) { { slack_users: [{ name: slack_domains[0].name, memberid: after_memberid }] } }
          let(:expect_slack_users) { { slack_domains[0].name => after_memberid } }
          let(:except_memberids) { expect_slack_users.merge(slack_domains[1].name => nil) }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'OK(json)'
          it_behaves_like 'ToOK(json)'
        end
        context '有効なパラメータ（SlackメンバーIDがない/最大文字数と同じ、Slackメンバーに存在する/しない、2件）' do
          let_it_be(:after_memberid) { 'B' * Settings.slack_user_memberid_maximum }
          let_it_be(:slack_user) { FactoryBot.create(:slack_user, slack_domain: slack_domains[0], user:, memberid: valid_memberid) }
          let(:params) do
            {
              slack_users: [
                { name: slack_domains[0].name, memberid: nil },
                { name: slack_domains[1].name, memberid: after_memberid }
              ]
            }
          end
          let(:expect_slack_users) do
            {
              slack_domains[0].name => nil,
              slack_domains[1].name => after_memberid
            }
          end
          let(:except_memberids) { expect_slack_users }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'OK(json)'
          it_behaves_like 'ToOK(json)'
        end
        context '無効なパラメータ（文字）' do
          let(:slack_user) { nil }
          let(:params) { { slack_users: 'x' } }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'NG(json)'
          it_behaves_like 'ToNG(json)', 422, {
            name1: [get_locale('errors.messages.param.blank')],
            memberid1: [get_locale('activerecord.errors.models.slack_user.attributes.memberid.blank')]
          }
        end
        context '無効なパラメータ（Slackドメイン名がない）' do
          let(:slack_user) { nil }
          let(:params) { { slack_users: [{ name: nil, memberid: valid_memberid }] } }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'NG(json)'
          it_behaves_like 'ToNG(json)', 422, { name1: [get_locale('errors.messages.param.blank')] }
        end
        context '無効なパラメータ（Slackドメイン名が存在しない）' do
          let(:slack_user) { nil }
          let(:params) { { slack_users: [{ name: '_', memberid: valid_memberid }] } }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'NG(json)'
          it_behaves_like 'ToNG(json)', 422, { name1: [get_locale('errors.messages.param.not_exist')] }
        end
        context '無効なパラメータ（Slackドメイン名に未参加）' do
          let(:slack_user) { nil }
          let(:params) { { slack_users: [{ name: other_send_setting.slack_domain.name, memberid: valid_memberid }] } }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'NG(json)'
          it_behaves_like 'ToNG(json)', 422, { name1: [get_locale('errors.messages.param.not_exist')] }
        end
        context '無効なパラメータ（SlackメンバーIDが最小文字数より少ない）' do
          let(:slack_user) { nil }
          let(:params) { { slack_users: [{ name: slack_domains[0].name, memberid: 'A' * (Settings.slack_user_memberid_minimum - 1) }] } }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'NG(json)'
          it_behaves_like 'ToNG(json)', 422, {
            memberid1: [get_locale('activerecord.errors.models.slack_user.attributes.memberid.too_short', count: Settings.slack_user_memberid_minimum)]
          }
        end
        context '無効なパラメータ（SlackメンバーIDが最大文字数より多い）' do
          let(:slack_user) { nil }
          let(:params) { { slack_users: [{ name: slack_domains[0].name, memberid: 'A' * (Settings.slack_user_memberid_maximum + 1) }] } }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'NG(json)'
          it_behaves_like 'ToNG(json)', 422, {
            memberid1: [get_locale('activerecord.errors.models.slack_user.attributes.memberid.too_long', count: Settings.slack_user_memberid_maximum)]
          }
        end
        context '無効なパラメータ（SlackメンバーIDが不正値）' do
          let(:slack_user) { nil }
          let(:params) { { slack_users: [{ name: slack_domains[0].name, memberid: '_' * Settings.slack_user_memberid_minimum }] } }
          it_behaves_like 'NG(html)'
          it_behaves_like 'ToNG(html)', 406
          it_behaves_like 'NG(json)'
          it_behaves_like 'ToNG(json)', 422, { memberid1: [get_locale('activerecord.errors.models.slack_user.attributes.memberid.invalid')] }
        end
      end
    end
    context 'APIログイン中（削除予約済み）' do
      include_context 'APIログイン処理', :destroy_reserved
      before_all { spaces.each { |space| FactoryBot.create(:member, space:, user:) } }
      let(:slack_user) { nil }
      let(:params) { { slack_users: [{ name: slack_domains[0].name, memberid: valid_memberid }] } }
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 422, nil, 'alert.user.destroy_reserved'
    end
  end
end
