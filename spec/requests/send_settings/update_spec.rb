require 'rails_helper'

RSpec.describe 'SendSetting', type: :request do
  let(:response_json) { response.parsed_body }
  let(:response_json_send_setting)       { response_json['send_setting'] }
  let(:response_json_current_slack_user) { response_json['current_slack_user'] }

  # POST /send_settings/:space_code/update(.json) 通知設定変更API(処理)
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開, 非公開（削除予約済み）
  #   権限: ある（管理者）, ない（投稿者, 閲覧者, なし）
  #   パラメータなし, 有効なパラメータ, 無効なパラメータ
  #     通知設定: ない, ある（変更あり/なし, 論理削除と一致）
  #     Slackドメイン: ない, ある（Slackユーザー: ない, ある）
  #     通知するがfalseで、Slackドメイン名/Webhook URL/メンション/アドレスが正常値/不正値
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'POST #update' do
    subject { post update_send_setting_path(space_code: space.code, format: subject_format), params:, headers: auth_headers.merge(accept_headers) }

    let_it_be(:valid_attributes) { FactoryBot.attributes_for(:send_setting, :changed, :slack, :email) }
    let_it_be(:valid_slack_name) { 'example' }
    let(:params_attributes) do
      {
        slack: {
          enabled: attributes[:slack_enabled],
          name: slack_name,
          webhook_url: attributes[:slack_webhook_url],
          mention: attributes[:slack_mention]
        },
        email: {
          enabled: attributes[:email_enabled],
          address: attributes[:email_address]
        },
        start_notice: {
          start_hour: attributes[:start_notice_start_hour],
          completed: attributes[:start_notice_completed],
          required: attributes[:start_notice_required]
        },
        next_notice: {
          start_hour: attributes[:next_notice_start_hour],
          completed: attributes[:next_notice_completed],
          required: attributes[:next_notice_required]
        }
      }
    end
    let_it_be(:created_user) { FactoryBot.create(:user) }

    shared_context 'valid_condition' do
      let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
      let_it_be(:member) { FactoryBot.create(:member, space:, user:) if user.present? }
      let(:attributes) { valid_attributes }
      let(:params) { { send_setting: params_attributes } }
      let(:slack_name) { valid_slack_name }
      let(:send_setting) { nil }
      let(:send_setting_inactive) { nil }
    end

    # テスト内容
    let(:current_send_setting) do
      SendSetting.active.where(space:).eager_load(:slack_domain, :last_updated_user).order(updated_at: :desc, id: :desc).first
    end
    let(:current_send_settings_inactive) { SendSetting.inactive.where(space:) }
    shared_examples_for 'OK' do
      let!(:start_time) { Time.current.floor }
      it '対象項目が変更される' do
        subject
        expect(current_send_setting.space).to eq(space)
        expect(current_send_setting.slack_domain&.name).to update_nil[:slack_name] ? be_nil : eq(slack_name)
        expect(current_send_setting.slack_enabled).to eq(attributes[:slack_enabled])
        expect(current_send_setting.slack_webhook_url).to update_nil[:slack_webhook_url] ? be_nil : eq(attributes[:slack_webhook_url])
        expect(current_send_setting.slack_mention).to update_nil[:slack_mention] ? be_nil : eq(attributes[:slack_mention])
        expect(current_send_setting.email_enabled).to eq(attributes[:email_enabled])
        expect(current_send_setting.email_address).to update_nil[:email_address] ? be_nil : eq(attributes[:email_address])
        expect(current_send_setting.start_notice_start_hour).to eq(attributes[:start_notice_start_hour])
        expect(current_send_setting.start_notice_completed).to eq(attributes[:start_notice_completed])
        expect(current_send_setting.start_notice_required).to eq(attributes[:start_notice_required])
        expect(current_send_setting.next_notice_start_hour).to eq(attributes[:next_notice_start_hour])
        expect(current_send_setting.next_notice_completed).to eq(attributes[:next_notice_completed])
        expect(current_send_setting.next_notice_required).to eq(attributes[:next_notice_required])
        expect(current_send_setting.last_updated_user_id).to be(user.id)

        if except_send_setting_inactive.present?
          expect(current_send_settings_inactive.count).to eq(1)
          current_send_setting_inactive = current_send_settings_inactive.first
          expect(current_send_setting_inactive.id).to eq(except_send_setting_inactive.id)
          expect(current_send_setting_inactive.last_updated_user_id).to eq(user.id)
          expect(current_send_setting_inactive.deleted_at).to be_between(start_time, Time.current)
          expect(current_send_setting_inactive.updated_at).to be_between(start_time, Time.current)
        else
          expect(current_send_settings_inactive.count).to eq(0)
        end
      end
    end
    shared_examples_for 'NG' do
      it '変更されない' do
        subject
        expect(current_send_setting).to eq(send_setting)
        expect(current_send_settings_inactive.count).to eq(send_setting_inactive.present? ? 1 : 0)
        expect(current_send_settings_inactive.first).to eq(send_setting_inactive) if send_setting_inactive.present?
      end
    end

    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)
        result = 3
        expect(response_json['success']).to be(true)
        expect(response_json['notice']).to eq(get_locale('notice.send_setting.update'))

        count = expect_send_setting_json(response_json_send_setting, current_send_setting, member)
        expect(response_json_send_setting.count).to eq(count)

        if slack_user.present?
          expect(response_json_current_slack_user['memberid']).to eq(slack_user.memberid)
          expect(response_json_current_slack_user.count).to eq(1)
          result += 1
        else
          expect(response_json_current_slack_user).to be_nil
        end
        expect(response_json.count).to eq(result)
      end
    end

    # テストケース
    shared_examples_for '[APIログイン中][*]権限がある' do |power|
      let_it_be(:member) { FactoryBot.create(:member, power, space:, user:) }
      context 'パラメータなし' do
        let(:params) { nil }
        let(:send_setting) { nil }
        let(:send_setting_inactive) { nil }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'NG(json)'
        it_behaves_like 'ToNG(json)', 422, {
          slack_enabled: [get_locale('activerecord.errors.models.send_setting.attributes.slack_enabled.inclusion')],
          email_enabled: [get_locale('activerecord.errors.models.send_setting.attributes.email_enabled.inclusion')],
          start_notice_start_hour: [get_locale('activerecord.errors.models.send_setting.attributes.start_notice_start_hour.blank')],
          start_notice_completed: [get_locale('activerecord.errors.models.send_setting.attributes.start_notice_completed.inclusion')],
          start_notice_required: [get_locale('activerecord.errors.models.send_setting.attributes.start_notice_required.inclusion')],
          next_notice_start_hour: [get_locale('activerecord.errors.models.send_setting.attributes.next_notice_start_hour.blank')],
          next_notice_completed: [get_locale('activerecord.errors.models.send_setting.attributes.next_notice_completed.inclusion')],
          next_notice_required: [get_locale('activerecord.errors.models.send_setting.attributes.next_notice_required.inclusion')]
        }
      end
      context '有効なパラメータ（Slackドメイン名が最大文字数と同じ、通知設定がない、Slackドメインがない）' do
        let(:attributes) { valid_attributes }
        let(:params) { { send_setting: params_attributes } }
        let(:slack_name) { 'a' * Settings.slack_domain_name_maximum }
        let(:send_setting) { nil }
        let(:send_setting_inactive) { nil }
        let(:except_send_setting_inactive) { nil }
        let(:slack_user) { nil }
        let(:update_nil) { {} }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'OK(json)'
        it_behaves_like 'ToOK(json)'
      end
      context '有効なパラメータ（通知設定がある（変更あり）、Slackドメインがない）' do
        let(:attributes) { valid_attributes }
        let(:params) { { send_setting: params_attributes } }
        let(:slack_name) { valid_slack_name }
        let_it_be(:send_setting) { FactoryBot.create(:send_setting, :slack, :email, :before_updated, space:) }
        let(:send_setting_inactive) { nil }
        let(:except_send_setting_inactive) { send_setting }
        let(:slack_user) { nil }
        let(:update_nil) { {} }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'OK(json)'
        it_behaves_like 'ToOK(json)'
      end
      context '有効なパラメータ（通知設定がある（変更なし）、Slackドメインがある（Slackユーザーがない））' do
        let(:attributes) { valid_attributes }
        let(:params) { { send_setting: params_attributes } }
        let_it_be(:slack_name) { valid_slack_name }
        let_it_be(:send_setting) do
          slack_domain = FactoryBot.create(:slack_domain, name: slack_name)
          FactoryBot.create(:send_setting, :before_updated, **valid_attributes, space:, slack_domain:)
        end
        let(:send_setting_inactive) { nil }
        let(:except_send_setting_inactive) { nil }
        let(:slack_user) { nil }
        let(:update_nil) { {} }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'OK(json)'
        it_behaves_like 'ToOK(json)'
      end
      context '有効なパラメータ（通知設定がある（論理削除と一致）、Slackドメインがある（Slackユーザーがある））' do
        let(:attributes) { valid_attributes }
        let(:params) { { send_setting: params_attributes } }
        let_it_be(:slack_name) { valid_slack_name }
        let_it_be(:send_setting) { FactoryBot.create(:send_setting, :slack, :email, :before_updated, space:) }
        let_it_be(:slack_domain) { FactoryBot.create(:slack_domain, name: slack_name) }
        let_it_be(:send_setting_inactive) do
          FactoryBot.create(:send_setting, :deleted, :before_updated, **valid_attributes, space:, slack_domain:)
        end
        let(:except_send_setting_inactive) { send_setting }
        let_it_be(:slack_user) { FactoryBot.create(:slack_user, slack_domain:, user:) }
        let(:update_nil) { {} }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'OK(json)'
        it_behaves_like 'ToOK(json)'
      end
      context '有効なパラメータ（通知するがfalseで、Slackドメイン名/Webhook URL/メンション/アドレスが正常値）' do
        let(:attributes) { valid_attributes.merge(slack_enabled: false, email_enabled: false) }
        let(:params) { { send_setting: params_attributes } }
        let(:slack_name) { valid_slack_name }
        let(:send_setting) { nil }
        let(:send_setting_inactive) { nil }
        let(:except_send_setting_inactive) { nil }
        let(:slack_user) { nil }
        let(:update_nil) { { slack_name: false, slack_webhook_url: false, slack_mention: false, email_address: false } }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'OK(json)'
        it_behaves_like 'ToOK(json)'
      end
      context '有効なパラメータ（通知するがfalseで、Slackドメイン名/Webhook URL/メンション/アドレスが不正値）' do
        let(:attributes) do
          valid_attributes.merge(
            slack_enabled: false,
            slack_webhook_url: "?#{valid_attributes[:slack_webhook_url]}",
            slack_mention: "?#{valid_attributes[:slack_mention]}",
            email_enabled: false,
            email_address: 'a'
          )
        end
        let(:params) { { send_setting: params_attributes } }
        let(:slack_name) { '_' }
        let(:send_setting) { nil }
        let(:send_setting_inactive) { nil }
        let(:except_send_setting_inactive) { nil }
        let(:slack_user) { nil }
        let(:update_nil) { { slack_name: true, slack_webhook_url: true, slack_mention: true, email_address: true } }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'OK(json)'
        it_behaves_like 'ToOK(json)'
      end
      context '無効なパラメータ' do
        let(:attributes) { valid_attributes }
        let(:params) { { send_setting: params_attributes } }
        let(:slack_name) { nil }
        let(:send_setting) { nil }
        let(:send_setting_inactive) { nil }
        it_behaves_like 'NG(html)'
        it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
        it_behaves_like 'NG(json)'
        it_behaves_like 'ToNG(json)', 422, { slack_name: [get_locale('activerecord.errors.models.slack_domain.attributes.name.blank')] }
      end
    end
    shared_examples_for '[APIログイン中][*]権限がない' do |power|
      let_it_be(:member) { FactoryBot.create(:member, power, space:, user:) if power.present? }
      let(:attributes) { valid_attributes }
      let(:params) { { send_setting: params_attributes } }
      let(:slack_name) { valid_slack_name }
      let(:send_setting) { nil }
      let(:send_setting_inactive) { nil }
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[APIログイン中][*]' do
      it_behaves_like '[APIログイン中][*]権限がある', :admin
      it_behaves_like '[APIログイン中][*]権限がない', :writer
      it_behaves_like '[APIログイン中][*]権限がない', :reader
      it_behaves_like '[APIログイン中][*]権限がない', nil
    end

    shared_examples_for '[APIログイン中]スペースが存在しない' do
      let_it_be(:space) { FactoryBot.build_stubbed(:space) }
      let(:attributes) { valid_attributes }
      let(:params) { { send_setting: params_attributes } }
      let(:slack_name) { valid_slack_name }
      # it_behaves_like 'NG(html)' # NOTE: 存在しない為
      it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
      # it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 404
    end
    shared_examples_for '[APIログイン中]スペースが公開' do
      let_it_be(:space) { FactoryBot.create(:space, :public, created_user:) }
      it_behaves_like '[APIログイン中][*]'
    end
    shared_examples_for '[APIログイン中]スペースが非公開' do
      let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
      it_behaves_like '[APIログイン中][*]'
    end
    shared_examples_for '[APIログイン中]スペースが非公開（削除予約済み）' do
      let_it_be(:space) { FactoryBot.create(:space, :private, :destroy_reserved, created_user:) }
      let(:attributes) { valid_attributes }
      let(:params) { { send_setting: params_attributes } }
      let(:slack_name) { valid_slack_name }
      let(:send_setting) { nil }
      let(:send_setting_inactive) { nil }
      let_it_be(:member) { FactoryBot.create(:member, space:, user:) }
      it_behaves_like 'NG(html)'
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'NG(json)'
      it_behaves_like 'ToNG(json)', 422, nil, 'alert.space.destroy_reserved'
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
      it_behaves_like '[APIログイン中]スペースが非公開（削除予約済み）'
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
