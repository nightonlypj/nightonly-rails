require 'rails_helper'

RSpec.describe SlackDomain, type: :model do
  # ドメイン名
  # テストパターン
  #   ない, 最大文字数と同じ, 最大文字数より多い, 不正値, 重複
  describe 'validates :name' do
    let(:model) { FactoryBot.build_stubbed(:slack_domain, name:) }

    # テストケース
    context 'ない' do
      let(:name) { nil }
      let(:messages) { { name: [get_locale('activerecord.errors.models.slack_domain.attributes.name.blank')] } }
      it_behaves_like 'InValid'
    end
    context '最大文字数と同じ' do
      let(:name) { 'a' * Settings.slack_domain_name_maximum }
      it_behaves_like 'Valid'
    end
    context '最大文字数より多い' do
      let(:name) { 'a' * (Settings.slack_domain_name_maximum + 1) }
      let(:messages) do
        { name: [get_locale('activerecord.errors.models.slack_domain.attributes.name.too_long', count: Settings.slack_domain_name_maximum)] }
      end
      it_behaves_like 'InValid'
    end
    context '不正値' do
      let(:name) { '_' }
      let(:messages) { { name: [get_locale('activerecord.errors.models.slack_domain.attributes.name.invalid')] } }
      it_behaves_like 'InValid'
    end
    context '重複' do
      before { FactoryBot.create(:slack_domain, name:) }
      let(:name) { 'a' }
      let(:messages) { { name: [get_locale('activerecord.errors.models.slack_domain.attributes.name.taken')] } }
      it_behaves_like 'InValid'
    end
  end
end
