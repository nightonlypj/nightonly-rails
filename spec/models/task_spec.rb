require 'rails_helper'

RSpec.describe Task, type: :model do
  # 最終更新日時
  # テストパターン
  #   更新日時: 作成日時と同じ, 作成日時以降
  describe '#last_updated_at' do
    subject { task.last_updated_at }

    # テストケース
    context '更新日時が作成日時と同じ' do
      let(:task) { FactoryBot.create(:task) }
      it 'なし' do
        is_expected.to eq(nil)
      end
    end
    context '更新日時が作成日時以降' do
      let(:task) { FactoryBot.create(:task, created_at: Time.current - 1.hour, updated_at: Time.current) }
      it '更新日時' do
        is_expected.to eq(task.updated_at)
      end
    end
  end
end
