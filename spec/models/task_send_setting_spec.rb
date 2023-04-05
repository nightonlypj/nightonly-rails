require 'rails_helper'

RSpec.describe TaskSendSetting, type: :model do
  # TODO

  # 最終更新日時
  # テストパターン
  #   更新日時: 作成日時と同じ, 作成日時以降
  describe '#last_updated_at' do
    subject { task_send_setting.last_updated_at }

    # テストケース
    context '更新日時が作成日時と同じ' do
      let(:task_send_setting) { FactoryBot.create(:task_send_setting) }
      it 'なし' do
        is_expected.to eq(nil)
      end
    end
    context '更新日時が作成日時以降' do
      let(:task_send_setting) { FactoryBot.create(:task_send_setting, created_at: Time.current - 1.hour, updated_at: Time.current) }
      it '更新日時' do
        is_expected.to eq(task_send_setting.updated_at)
      end
    end
  end
end
