require 'rails_helper'

RSpec.describe SlackUser, type: :model do
  # SlackメンバーID
  # テストパターン
  #   ない, 最小文字数より少ない, 最小文字数と同じ, 最大文字数と同じ, 最大文字数より多い, 不正値
  describe 'validates :memberid' do
    subject(:model) { FactoryBot.build_stubbed(:slack_user, memberid:) }

    # テストケース
    context 'ない' do
      let(:memberid) { nil }
      let(:messages) { { memberid: [get_locale('activerecord.errors.models.slack_user.attributes.memberid.blank')] } }
      it_behaves_like 'Valid'
    end
    context '最小文字数より少ない' do
      let(:memberid) { 'A' * (Settings.slack_user_memberid_minimum - 1) }
      let(:messages) do
        { memberid: [get_locale('activerecord.errors.models.slack_user.attributes.memberid.too_short', count: Settings.slack_user_memberid_minimum)] }
      end
      it_behaves_like 'InValid'
    end
    context '最小文字数と同じ' do
      let(:memberid) { 'A' * Settings.slack_user_memberid_minimum }
      it_behaves_like 'Valid'
    end
    context '最大文字数と同じ' do
      let(:memberid) { 'A' * Settings.slack_user_memberid_maximum }
      it_behaves_like 'Valid'
    end
    context '最大文字数より多い' do
      let(:memberid) { 'A' * (Settings.slack_user_memberid_maximum + 1) }
      let(:messages) do
        { memberid: [get_locale('activerecord.errors.models.slack_user.attributes.memberid.too_long', count: Settings.slack_user_memberid_maximum)] }
      end
      it_behaves_like 'InValid'
    end
    context '不正値' do
      let(:memberid) { '_' * Settings.slack_user_memberid_minimum }
      let(:messages) { { memberid: [get_locale('activerecord.errors.models.slack_user.attributes.memberid.invalid')] } }
      it_behaves_like 'InValid'
    end
  end
end
