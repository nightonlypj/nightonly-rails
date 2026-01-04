require 'rails_helper'

RSpec.describe Task, type: :model do
  # 優先度
  # テストパターン
  #   ない, 正常値
  describe 'validates :priority' do
    subject(:model) { FactoryBot.build_stubbed(:task, priority:) }

    # テストケース
    context 'ない' do
      let(:priority) { nil }
      let(:messages) { { priority: [get_locale('activerecord.errors.models.task.attributes.priority.blank')] } }
      it_behaves_like 'InValid'
    end
    context '正常値' do
      let(:priority) { :high }
      it_behaves_like 'Valid'
    end
  end

  # タイトル
  # テストパターン
  #   ない, 最大文字数と同じ, 最大文字数より多い
  describe 'validates :title' do
    subject(:model) { FactoryBot.build_stubbed(:task, title:, summary: nil, premise: nil, process: nil) }

    # テストケース
    context 'ない' do
      let(:title) { nil }
      let(:messages) { { title: [get_locale('activerecord.errors.models.task.attributes.title.blank')] } }
      it_behaves_like 'InValid'
    end
    context '最大文字数と同じ' do
      let(:title) { 'a' * Settings.task_title_maximum }
      it_behaves_like 'Valid'
    end
    context '最大文字数より多い' do
      let(:title) { 'a' * (Settings.task_title_maximum + 1) }
      let(:messages) { { title: [get_locale('activerecord.errors.models.task.attributes.title.too_long', count: Settings.task_title_maximum)] } }
      it_behaves_like 'InValid'
    end
  end

  # 概要
  # テストパターン
  #   ない, 最大文字数と同じ, 最大文字数より多い
  describe 'validates :summary' do
    subject(:model) { FactoryBot.build_stubbed(:task, summary:) }

    # テストケース
    context 'ない' do
      let(:summary) { nil }
      it_behaves_like 'Valid'
    end
    context '最大文字数と同じ' do
      let(:summary) { 'a' * Settings.task_summary_maximum }
      it_behaves_like 'Valid'
    end
    context '最大文字数より多い' do
      let(:summary) { 'a' * (Settings.task_summary_maximum + 1) }
      let(:messages) { { summary: [get_locale('activerecord.errors.models.task.attributes.summary.too_long', count: Settings.task_summary_maximum)] } }
      it_behaves_like 'InValid'
    end
  end

  # 前提
  # テストパターン
  #   ない, 最大文字数と同じ, 最大文字数より多い
  describe 'validates :premise' do
    subject(:model) { FactoryBot.build_stubbed(:task, premise:) }

    # テストケース
    context 'ない' do
      let(:premise) { nil }
      it_behaves_like 'Valid'
    end
    context '最大文字数と同じ' do
      let(:premise) { 'a' * Settings.task_premise_maximum }
      it_behaves_like 'Valid'
    end
    context '最大文字数より多い' do
      let(:premise) { 'a' * (Settings.task_premise_maximum + 1) }
      let(:messages) { { premise: [get_locale('activerecord.errors.models.task.attributes.premise.too_long', count: Settings.task_premise_maximum)] } }
      it_behaves_like 'InValid'
    end
  end

  # 手順
  # テストパターン
  #   ない, 最大文字数と同じ, 最大文字数より多い
  describe 'validates :process' do
    subject(:model) { FactoryBot.build_stubbed(:task, process:) }

    # テストケース
    context 'ない' do
      let(:process) { nil }
      it_behaves_like 'Valid'
    end
    context '最大文字数と同じ' do
      let(:process) { 'a' * Settings.task_process_maximum }
      it_behaves_like 'Valid'
    end
    context '最大文字数より多い' do
      let(:process) { 'a' * (Settings.task_process_maximum + 1) }
      let(:messages) { { process: [get_locale('activerecord.errors.models.task.attributes.process.too_long', count: Settings.task_process_maximum)] } }
      it_behaves_like 'InValid'
    end
  end

  # 開始日
  # テストパターン
  #   登録
  #     ない, 現在日, 過去日
  #   更新
  #     変更なし, ない, 過去日, 現在日
  describe 'validates :started_date' do
    # テストケース
    context '登録' do
      subject(:model) { FactoryBot.build(:task, started_date:, ended_date: nil) }
      context 'ない' do
        let(:started_date) { nil }
        let(:messages) { { started_date: [get_locale('activerecord.errors.models.task.attributes.started_date.blank')] } }
        it_behaves_like 'InValid'
      end
      context '現在日' do
        let(:started_date) { Time.zone.today }
        it_behaves_like 'Valid'
      end
      context '過去日' do
        let(:started_date) { Time.zone.today - 1.day }
        let(:messages) { { started_date: [get_locale('activerecord.errors.models.task.attributes.started_date.before')] } }
        it_behaves_like 'InValid'
      end
    end
    context '更新' do
      let(:started_date) { Time.zone.today - 1.day }
      context '変更なし' do
        subject(:model) { FactoryBot.create(:task, :skip_validate, started_date:, ended_date: nil) }
        it_behaves_like 'Valid'
      end
      context 'ない' do
        subject(:model) do
          result = FactoryBot.create(:task, :skip_validate, started_date:, ended_date: nil)
          result.started_date = nil

          result
        end
        let(:messages) { { started_date: [get_locale('activerecord.errors.models.task.attributes.started_date.blank')] } }
        it_behaves_like 'InValid'
      end
      context '過去日' do
        subject(:model) do
          result = FactoryBot.create(:task, :skip_validate, started_date:, ended_date: nil)
          result.started_date = Time.zone.today - 2.days

          result
        end
        let(:messages) { { started_date: [get_locale('activerecord.errors.models.task.attributes.started_date.before')] } }
        it_behaves_like 'InValid'
      end
      context '現在日' do
        subject(:model) do
          result = FactoryBot.create(:task, :skip_validate, started_date:, ended_date: nil)
          result.started_date = Time.zone.today

          result
        end
        it_behaves_like 'Valid'
      end
    end
  end

  # 終了日
  # テストパターン
  #   ない, 開始日より前, 開始日と同じ, 開始日より後
  describe 'validates :ended_date' do
    subject(:model) { FactoryBot.build_stubbed(:task, started_date:, ended_date:) }
    let(:started_date) { Time.zone.today }

    # テストケース
    context 'ない' do
      let(:ended_date) { nil }
      it_behaves_like 'Valid'
    end
    context '開始日より前' do
      let(:ended_date) { started_date - 1.day }
      let(:messages) { { ended_date: [get_locale('activerecord.errors.models.task.attributes.ended_date.after')] } }
      it_behaves_like 'InValid'
    end
    context '開始日と同じ' do
      let(:ended_date) { started_date }
      it_behaves_like 'Valid'
    end
    context '開始日より後' do
      let(:ended_date) { started_date + 1.day }
      it_behaves_like 'Valid'
    end
  end

  # 最終更新日時
  # テストパターン
  #   更新日時: 作成日時と同じ, 作成日時以降
  describe '#last_updated_at' do
    subject { task.last_updated_at }
    let(:created_at) { 1.day.ago }

    # テストケース
    context '更新日時が作成日時と同じ' do
      let(:task) { FactoryBot.create(:task, created_at:, updated_at: created_at) }
      it_behaves_like 'Value', nil, 'nil'
    end
    context '更新日時が作成日時以降' do
      let(:task) { FactoryBot.create(:task, created_at:, updated_at: Time.current) }
      it '更新日時' do
        is_expected.to eq(task.updated_at)
      end
    end
  end
end
