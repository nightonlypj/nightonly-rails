require 'rails_helper'

RSpec.describe SendSetting, type: :model do
  # (Slack)通知する
  # テストパターン
  #   ない, true, false, 文字
  describe 'validates :slack_enabled' do
    subject(:model) { FactoryBot.build_stubbed(:send_setting, :slack, slack_enabled:) }

    # テストケース
    context 'ない' do
      let(:slack_enabled) { nil }
      let(:messages) { { slack_enabled: [get_locale('activerecord.errors.models.send_setting.attributes.slack_enabled.inclusion')] } }
      it_behaves_like 'InValid'
    end
    context 'true' do
      let(:slack_enabled) { true }
      it_behaves_like 'Valid'
    end
    context 'false' do
      let(:slack_enabled) { false }
      it_behaves_like 'Valid'
    end
    context '文字' do
      let(:slack_enabled) { 'a' }
      it_behaves_like 'Valid' # NOTE: trueになる
    end
  end

  # (Slack)Webhook URL
  # テストパターン
  #   Webhook URL: ない, 最大文字数と同じ, 最大文字数より多い, 不正値
  #   通知: する, しない
  describe 'validates :slack_webhook_url' do
    subject(:model) { FactoryBot.build_stubbed(:send_setting, :slack, slack_enabled:, slack_webhook_url:) }
    let(:url) { Faker::Internet.url(scheme: 'https') }
    let(:url_maximum) { url + ('a' * (Settings.slack_webhook_url_maximum - url.length)) }

    # テストケース
    shared_examples '[InValid]通知' do
      context 'する' do
        let(:slack_enabled) { true }
        it_behaves_like 'InValid'
      end
      context 'しない' do
        let(:slack_enabled) { false }
        it_behaves_like 'InValid'
      end
    end

    context 'Webhook URLがない' do
      let(:slack_enabled) { true }
      let(:slack_webhook_url) { nil }
      let(:messages) { { slack_webhook_url: [get_locale('activerecord.errors.models.send_setting.attributes.slack_webhook_url.blank')] } }
      it_behaves_like 'InValid'
    end
    context 'Webhook URLが最大文字数と同じ' do
      let(:slack_enabled) { true }
      let(:slack_webhook_url) { url_maximum }
      it_behaves_like 'Valid'
    end
    context 'Webhook URLが最大文字数より多い' do
      let(:slack_webhook_url) { "?#{url_maximum}" } # NOTE: 不正値と一緒に出ないことも確認
      let(:messages) do
        {
          slack_webhook_url: [
            get_locale('activerecord.errors.models.send_setting.attributes.slack_webhook_url.too_long', count: Settings.slack_webhook_url_maximum)
          ]
        }
      end
      it_behaves_like '[InValid]通知'
    end
    context 'Webhook URLが不正値' do
      let(:slack_webhook_url) { "?#{url}" }
      let(:messages) { { slack_webhook_url: [get_locale('activerecord.errors.models.send_setting.attributes.slack_webhook_url.invalid')] } }
      it_behaves_like '[InValid]通知'
    end
  end

  # (Slack)メンション
  # テストパターン
  #   メンション: ない, 最大文字数と同じ, 最大文字数より多い, 不正値
  #   通知: する, しない
  describe 'validates :slack_mention' do
    subject(:model) { FactoryBot.build_stubbed(:send_setting, :slack, slack_enabled:, slack_mention:) }
    let(:mention) { '!here' }
    let(:mention_maximum) { mention + ('a' * (Settings.slack_mention_maximum - mention.length)) }

    # テストケース
    shared_examples '[InValid]通知' do
      context 'する' do
        let(:slack_enabled) { true }
        it_behaves_like 'InValid'
      end
      context 'しない' do
        let(:slack_enabled) { false }
        it_behaves_like 'InValid'
      end
    end

    context 'メンションがない' do
      let(:slack_enabled) { true }
      let(:slack_mention) { nil }
      it_behaves_like 'Valid'
    end
    context 'メンションが最大文字数と同じ' do
      let(:slack_enabled) { true }
      let(:slack_mention) { mention_maximum }
      it_behaves_like 'Valid'
    end
    context 'メンションが最大文字数より多い' do
      let(:slack_mention) { "?#{mention_maximum}" } # NOTE: 不正値と一緒に出ないことも確認
      let(:messages) do
        { slack_mention: [get_locale('activerecord.errors.models.send_setting.attributes.slack_mention.too_long', count: Settings.slack_mention_maximum)] }
      end
      it_behaves_like '[InValid]通知'
    end
    context 'メンションが不正値' do
      let(:slack_mention) { "?#{mention}" }
      let(:messages) { { slack_mention: [get_locale('activerecord.errors.models.send_setting.attributes.slack_mention.invalid')] } }
      it_behaves_like '[InValid]通知'
    end
  end

  # (メール)通知する
  # テストパターン
  #   ない, true, false, 文字
  describe 'validates :email_enabled' do
    subject(:model) { FactoryBot.build_stubbed(:send_setting, :email, email_enabled:) }

    # テストケース
    context 'ない' do
      let(:email_enabled) { nil }
      let(:messages) { { email_enabled: [get_locale('activerecord.errors.models.send_setting.attributes.email_enabled.inclusion')] } }
      it_behaves_like 'InValid'
    end
    context 'true' do
      let(:email_enabled) { true }
      it_behaves_like 'Valid'
    end
    context 'false' do
      let(:email_enabled) { false }
      it_behaves_like 'Valid'
    end
    context '文字' do
      let(:email_enabled) { 'a' }
      it_behaves_like 'Valid' # NOTE: trueになる
    end
  end

  # (メール)アドレス
  # テストパターン
  #   アドレス: ない, 正常, 不正値
  #   通知: する, しない
  describe 'validates :email_address' do
    subject(:model) { FactoryBot.build_stubbed(:send_setting, :email, email_enabled:, email_address:) }

    # テストケース
    shared_examples '[InValid]通知' do
      context 'する' do
        let(:email_enabled) { true }
        it_behaves_like 'InValid'
      end
      context 'しない' do
        let(:email_enabled) { false }
        it_behaves_like 'InValid'
      end
    end

    context 'アドレスがない' do
      let(:email_enabled) { true }
      let(:email_address) { nil }
      let(:messages) { { email_address: [get_locale('activerecord.errors.models.send_setting.attributes.email_address.blank')] } }
      it_behaves_like 'InValid'
    end
    context 'アドレスが正常' do
      let(:email_enabled) { true }
      let(:email_address) { Faker::Internet.email }
      it_behaves_like 'Valid'
    end
    context 'アドレスが不正値' do
      let(:email_address) { 'a' }
      let(:messages) { { email_address: [get_locale('activerecord.errors.models.send_setting.attributes.email_address.invalid')] } }
      it_behaves_like '[InValid]通知'
    end
  end

  # (開始確認)開始時間
  # 前提条件
  #   (翌営業日・終了確認)開始時間が23
  # テストパターン
  #   ない, -1, 0, 22, 23, 文字
  describe 'validates :start_notice_start_hour' do
    subject(:model) { FactoryBot.build_stubbed(:send_setting, start_notice_start_hour:, next_notice_start_hour: 23) }

    # テストケース
    context 'ない' do
      let(:start_notice_start_hour) { nil }
      let(:messages) { { start_notice_start_hour: [get_locale('activerecord.errors.models.send_setting.attributes.start_notice_start_hour.blank')] } }
      it_behaves_like 'InValid'
    end
    context '-1' do
      let(:start_notice_start_hour) { -1 }
      let(:messages) do
        {
          start_notice_start_hour: [get_locale('activerecord.errors.models.send_setting.attributes.start_notice_start_hour.greater_than_or_equal_to', count: 0)]
        }
      end
      it_behaves_like 'InValid'
    end
    context '0' do
      let(:start_notice_start_hour) { 0 }
      it_behaves_like 'Valid'
    end
    context '22' do
      let(:start_notice_start_hour) { 22 }
      it_behaves_like 'Valid'
    end
    context '23' do
      let(:start_notice_start_hour) { 23 }
      let(:messages) do
        { start_notice_start_hour: [get_locale('activerecord.errors.models.send_setting.attributes.start_notice_start_hour.less_than_or_equal_to', count: 22)] }
      end
      it_behaves_like 'InValid'
    end
    context '文字' do
      let(:start_notice_start_hour) { 'a' }
      it_behaves_like 'Valid' # NOTE: 0になる
    end
  end

  # (開始確認)完了通知
  # テストパターン
  #   ない, true, false, 文字
  describe 'validates :start_notice_completed' do
    subject(:model) { FactoryBot.build_stubbed(:send_setting, start_notice_completed:) }

    # テストケース
    context 'ない' do
      let(:start_notice_completed) { nil }
      let(:messages) { { start_notice_completed: [get_locale('activerecord.errors.models.send_setting.attributes.start_notice_completed.inclusion')] } }
      it_behaves_like 'InValid'
    end
    context 'true' do
      let(:start_notice_completed) { true }
      it_behaves_like 'Valid'
    end
    context 'false' do
      let(:start_notice_completed) { false }
      it_behaves_like 'Valid'
    end
    context '文字' do
      let(:start_notice_completed) { 'a' }
      it_behaves_like 'Valid' # NOTE: trueになる
    end
  end

  # (開始確認)必ず通知
  # テストパターン
  #   ない, true, false, 文字
  describe 'validates :start_notice_required' do
    subject(:model) { FactoryBot.build_stubbed(:send_setting, start_notice_required:) }

    # テストケース
    context 'ない' do
      let(:start_notice_required) { nil }
      let(:messages) { { start_notice_required: [get_locale('activerecord.errors.models.send_setting.attributes.start_notice_required.inclusion')] } }
      it_behaves_like 'InValid'
    end
    context 'true' do
      let(:start_notice_required) { true }
      it_behaves_like 'Valid'
    end
    context 'false' do
      let(:start_notice_required) { false }
      it_behaves_like 'Valid'
    end
    context '文字' do
      let(:start_notice_required) { 'a' }
      it_behaves_like 'Valid' # NOTE: trueになる
    end
  end

  # (翌営業日・終了確認)開始時間
  # テストパターン
  #   (開始確認)開始時間が0
  #     ない, 0, 1, 23, 24, 文字
  #   (開始確認)開始時間が10
  #     10, 11
  describe 'validates :next_notice_start_hour' do
    subject(:model) { FactoryBot.build_stubbed(:send_setting, start_notice_start_hour:, next_notice_start_hour:) }

    # テストケース
    context '(開始確認)開始時間が0' do
      let(:start_notice_start_hour) { 0 }
      context '(翌営業日・終了確認)開始時間がない' do
        let(:next_notice_start_hour) { nil }
        let(:messages) { { next_notice_start_hour: [get_locale('activerecord.errors.models.send_setting.attributes.next_notice_start_hour.blank')] } }
        it_behaves_like 'InValid'
      end
      context '(翌営業日・終了確認)開始時間が0' do
        let(:next_notice_start_hour) { 0 }
        let(:messages) do
          {
            next_notice_start_hour: [get_locale('activerecord.errors.models.send_setting.attributes.next_notice_start_hour.greater_than_or_equal_to', count: 1)]
          }
        end
        it_behaves_like 'InValid'
      end
      context '(翌営業日・終了確認)開始時間が1' do
        let(:next_notice_start_hour) { 1 }
        it_behaves_like 'Valid'
      end
      context '(翌営業日・終了確認)開始時間が23' do
        let(:next_notice_start_hour) { 23 }
        it_behaves_like 'Valid'
      end
      context '(翌営業日・終了確認)開始時間が24' do
        let(:next_notice_start_hour) { 24 }
        let(:messages) do
          { next_notice_start_hour: [get_locale('activerecord.errors.models.send_setting.attributes.next_notice_start_hour.less_than_or_equal_to', count: 23)] }
        end
        it_behaves_like 'InValid'
      end
      context '(翌営業日・終了確認)開始時間が文字' do
        let(:next_notice_start_hour) { 'a' }
        let(:messages) do
          {
            next_notice_start_hour: [get_locale('activerecord.errors.models.send_setting.attributes.next_notice_start_hour.greater_than_or_equal_to', count: 1)]
          }
        end
        it_behaves_like 'InValid' # NOTE: 0になる
      end
    end
    context '(開始確認)開始時間が10' do
      let(:start_notice_start_hour) { 10 }
      context '(翌営業日・終了確認)開始時間が10' do
        let(:next_notice_start_hour) { 10 }
        let(:messages) { { next_notice_start_hour: [get_locale('activerecord.errors.models.send_setting.attributes.next_notice_start_hour.invalid')] } }
        it_behaves_like 'InValid'
      end
      context '(翌営業日・終了確認)開始時間が11' do
        let(:next_notice_start_hour) { 11 }
        it_behaves_like 'Valid'
      end
    end
  end

  # (翌営業日・終了確認)完了通知
  # テストパターン
  #   ない, true, false, 文字
  describe 'validates :next_notice_completed' do
    subject(:model) { FactoryBot.build_stubbed(:send_setting, next_notice_completed:) }

    # テストケース
    context 'ない' do
      let(:next_notice_completed) { nil }
      let(:messages) { { next_notice_completed: [get_locale('activerecord.errors.models.send_setting.attributes.next_notice_completed.inclusion')] } }
      it_behaves_like 'InValid'
    end
    context 'true' do
      let(:next_notice_completed) { true }
      it_behaves_like 'Valid'
    end
    context 'false' do
      let(:next_notice_completed) { false }
      it_behaves_like 'Valid'
    end
    context '文字' do
      let(:next_notice_completed) { 'a' }
      it_behaves_like 'Valid' # NOTE: trueになる
    end
  end

  # (翌営業日・終了確認)必ず通知
  # テストパターン
  #   ない, true, false, 文字
  describe 'validates :next_notice_required' do
    subject(:model) { FactoryBot.build_stubbed(:send_setting, next_notice_required:) }

    # テストケース
    context 'ない' do
      let(:next_notice_required) { nil }
      let(:messages) { { next_notice_required: [get_locale('activerecord.errors.models.send_setting.attributes.next_notice_required.inclusion')] } }
      it_behaves_like 'InValid'
    end
    context 'true' do
      let(:next_notice_required) { true }
      it_behaves_like 'Valid'
    end
    context 'false' do
      let(:next_notice_required) { false }
      it_behaves_like 'Valid'
    end
    context '文字' do
      let(:next_notice_required) { 'a' }
      it_behaves_like 'Valid' # NOTE: trueになる
    end
  end
end
