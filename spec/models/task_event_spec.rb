require 'rails_helper'

RSpec.describe TaskEvent, type: :model do
  # テスト内容（共通）
  shared_examples_for 'Valid' do
    it '保存できる' do
      expect(task_event).to be_valid
    end
  end
  shared_examples_for 'InValid' do
    it '保存できない。エラーメッセージが一致する' do
      expect(task_event).to be_invalid
      expect(task_event.errors.messages).to eq(messages)
    end
  end

  # コード
  # テストパターン
  #   ない, 正常値, 重複
  describe 'validates :code' do
    let(:task_event) { FactoryBot.build_stubbed(:task_event, code: code) }
    let(:valid_code) { Digest::MD5.hexdigest(SecureRandom.uuid) }

    # テストケース
    context 'ない' do
      let(:code) { nil }
      let(:messages) { { code: [get_locale('activerecord.errors.models.task_event.attributes.code.blank')] } }
      it_behaves_like 'InValid'
    end
    context '正常値' do
      let(:code) { valid_code }
      it_behaves_like 'Valid'
    end
    context '重複' do
      before { FactoryBot.create(:task_event, code: code) }
      let(:code) { valid_code }
      let(:messages) { { code: [get_locale('activerecord.errors.models.task_event.attributes.code.taken')] } }
      it_behaves_like 'InValid'
    end
  end

  # ステータス
  # テストパターン
  #   ない, 正常値
  describe 'validates :status' do
    let(:task_event) { FactoryBot.build_stubbed(:task_event, status: status) }

    context 'ない' do
      let(:status) { nil }
      let(:messages) { { status: [get_locale('activerecord.errors.models.task_event.attributes.status.blank')] } }
      it_behaves_like 'InValid'
    end
    context '正常値' do
      let(:status) { :untreated }
      it_behaves_like 'Valid'
    end
  end

  # 概要
  # テストパターン
  #   ない, 最大文字数と同じ, 最大文字数よりも多い
  describe 'validates :memo' do
    let(:task_event) { FactoryBot.build_stubbed(:task_event, memo: memo) }

    # テストケース
    context 'ない' do
      let(:memo) { nil }
      it_behaves_like 'Valid'
    end
    context '最大文字数と同じ' do
      let(:memo) { 'a' * Settings.task_event_memo_maximum }
      it_behaves_like 'Valid'
    end
    context '最大文字数よりも多い' do
      let(:memo) { 'a' * (Settings.task_event_memo_maximum + 1) }
      let(:messages) { { memo: [get_locale('activerecord.errors.models.task_event.attributes.memo.too_long', count: Settings.task_event_memo_maximum)] } }
      it_behaves_like 'InValid'
    end
  end

  # 最終終了日
  # テストパターン
  #   開始日: ない, ある
  #   最終終了日: ない, 開始日より前, 開始日の翌月末, 開始日の翌々月初
  describe 'validates :last_ended_date' do
    let(:task_event) { FactoryBot.build_stubbed(:task_event, started_date: started_date, last_ended_date: last_ended_date) }
    let(:started_date) { Time.current.to_date }

    # テストケース
    context 'ない' do
      let(:last_ended_date) { nil }
      let(:messages) { { last_ended_date: [get_locale('activerecord.errors.models.task_event.attributes.last_ended_date.blank')] } }
      it_behaves_like 'InValid'
    end
    context '開始日より前' do
      let(:last_ended_date) { started_date - 1.day }
      let(:messages) { { last_ended_date: [get_locale('activerecord.errors.models.task_event.attributes.last_ended_date.after')] } }
      it_behaves_like 'InValid'
    end
    context '開始日の翌月末' do
      let(:last_ended_date) { (started_date + 1.month).end_of_month }
      it_behaves_like 'Valid'
    end
    context '開始日の翌々月初' do
      let(:last_ended_date) { (started_date + 2.months).beginning_of_month }
      let(:messages) { { last_ended_date: [get_locale('activerecord.errors.models.task_event.attributes.last_ended_date.before')] } }
      it_behaves_like 'InValid'
    end
  end

  # 最終更新日時
  # テストパターン
  #   更新日時: 作成日時と同じ, 作成日時以降
  describe '#last_updated_at' do
    subject { task_event.last_updated_at }

    # テストケース
    context '更新日時が作成日時と同じ' do
      let(:task_event) { FactoryBot.create(:task_event) }
      it 'なし' do
        is_expected.to eq(nil)
      end
    end
    context '更新日時が作成日時以降' do
      let(:task_event) { FactoryBot.create(:task_event, created_at: Time.current - 1.hour, updated_at: Time.current) }
      it '更新日時' do
        is_expected.to eq(task_event.updated_at)
      end
    end
  end
end
