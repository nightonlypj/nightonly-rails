require 'rails_helper'

RSpec.describe TaskEvent, type: :model do
  # コード
  # テストパターン
  #   ない, 正常値, 重複
  describe 'validates :code' do
    let(:model) { FactoryBot.build_stubbed(:task_event, code:) }
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
      before { FactoryBot.create(:task_event, code:) }
      let(:code) { valid_code }
      let(:messages) { { code: [get_locale('activerecord.errors.models.task_event.attributes.code.taken')] } }
      it_behaves_like 'InValid'
    end
  end

  # ステータス
  # テストパターン
  #   ない, 正常値
  describe 'validates :status' do
    let(:model) { FactoryBot.build_stubbed(:task_event, status:) }

    # テストケース
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
  #   ない, 最大文字数と同じ, 最大文字数より多い
  describe 'validates :memo' do
    let(:model) { FactoryBot.build_stubbed(:task_event, memo:) }

    # テストケース
    context 'ない' do
      let(:memo) { nil }
      it_behaves_like 'Valid'
    end
    context '最大文字数と同じ' do
      let(:memo) { 'a' * Settings.task_event_memo_maximum }
      it_behaves_like 'Valid'
    end
    context '最大文字数より多い' do
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
    let(:model) { FactoryBot.build_stubbed(:task_event, started_date:, last_ended_date:) }
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
      it_behaves_like 'Value', nil, 'nil'
    end
    context '更新日時が作成日時以降' do
      let(:task_event) { FactoryBot.create(:task_event, created_at: Time.current - 1.hour, updated_at: Time.current) }
      it '更新日時' do
        is_expected.to eq(task_event.updated_at)
      end
    end
  end

  # Slackのステータス毎のアイコンを返却
  # テストパターン
  #   ステータス: 未処理, 前提対応待ち, 前提確認済み, 処理中, 保留, 確認待ち, 完了, 対応不要
  #   担当者: いない, いる
  #   翌営業日開始のタスク, 期限切れのタスク, 本日期限のタスク, 期限内のタスク, (前営業日以降に/本日)完了したタスク
  #   通知対象: 開始確認, 翌営業日・終了確認
  describe '#slack_status_icon' do
    subject { task_event.slack_status_icon(type, notice_target) }
    let_it_be(:user) { FactoryBot.create(:user) }

    # テスト内容
    shared_examples_for 'OK' do |params, value|
      let(:type) { params[:type] }
      let(:notice_target) { params[:notice_target] }
      it_behaves_like 'Value', value, "#{params}の場合、#{value}"
    end

    # テストケース
    shared_examples_for '[未処理/前提対応待ち/前提確認済み]担当者' do
      context 'いない' do
        let_it_be(:task_event) { FactoryBot.create(:task_event, status:) }
        it_behaves_like 'OK', { type: :next, notice_target: :start }, ':alarm_clock:'
        it_behaves_like 'OK', { type: :expired, notice_target: :start }, ':red_circle:'
        it_behaves_like 'OK', { type: :end_today, notice_target: :start }, ':warning:'
        it_behaves_like 'OK', { type: :date_include, notice_target: :start }, ':warning:'
        it_behaves_like 'OK', { type: :completed, notice_target: :start }, ':sunny:'
        it_behaves_like 'OK', { type: :next, notice_target: :next }, ':alarm_clock:'
        it_behaves_like 'OK', { type: :expired, notice_target: :next }, ':red_circle:'
        it_behaves_like 'OK', { type: :end_today, notice_target: :next }, ':warning:'
        it_behaves_like 'OK', { type: :date_include, notice_target: :next }, ':warning:'
        it_behaves_like 'OK', { type: :completed, notice_target: :next }, ':sunny:'
      end
      context 'いる' do
        let_it_be(:task_event) { FactoryBot.create(:task_event, status:, assigned_user: user) }
        it_behaves_like 'OK', { type: :next, notice_target: :start }, ':alarm_clock:'
        it_behaves_like 'OK', { type: :expired, notice_target: :start }, ':red_circle:'
        it_behaves_like 'OK', { type: :end_today, notice_target: :start }, ':cloud:' # <- warning
        it_behaves_like 'OK', { type: :date_include, notice_target: :start }, ':cloud:' # <- warning
        it_behaves_like 'OK', { type: :completed, notice_target: :start }, ':sunny:'
        it_behaves_like 'OK', { type: :next, notice_target: :next }, ':alarm_clock:'
        it_behaves_like 'OK', { type: :expired, notice_target: :next }, ':red_circle:'
        it_behaves_like 'OK', { type: :end_today, notice_target: :next }, ':umbrella:' # <- warning
        it_behaves_like 'OK', { type: :date_include, notice_target: :next }, ':cloud:' # <- warning
        it_behaves_like 'OK', { type: :completed, notice_target: :next }, ':sunny:'
      end
    end
    shared_examples_for '[処理中]担当者がいない/いる' do
      it_behaves_like 'OK', { type: :next, notice_target: :start }, ':alarm_clock:'
      it_behaves_like 'OK', { type: :expired, notice_target: :start }, ':red_circle:'
      it_behaves_like 'OK', { type: :end_today, notice_target: :start }, ':cloud:' # <- warning/cloud
      it_behaves_like 'OK', { type: :date_include, notice_target: :start }, ':sunny:' # <- warning/cloud
      it_behaves_like 'OK', { type: :completed, notice_target: :start }, ':sunny:'
      it_behaves_like 'OK', { type: :next, notice_target: :next }, ':alarm_clock:'
      it_behaves_like 'OK', { type: :expired, notice_target: :next }, ':red_circle:'
      it_behaves_like 'OK', { type: :end_today, notice_target: :next }, ':cloud:' # <- warning/umbrella
      it_behaves_like 'OK', { type: :date_include, notice_target: :next }, ':sunny:' # <- warning/cloud
      it_behaves_like 'OK', { type: :completed, notice_target: :next }, ':sunny:'
    end
    shared_examples_for '[保留]担当者がいない/いる' do
      it_behaves_like 'OK', { type: :next, notice_target: :start }, ':alarm_clock:'
      it_behaves_like 'OK', { type: :expired, notice_target: :start }, ':red_circle:'
      it_behaves_like 'OK', { type: :end_today, notice_target: :start }, ':cloud:'
      it_behaves_like 'OK', { type: :date_include, notice_target: :start }, ':cloud:' # <- sunny
      it_behaves_like 'OK', { type: :completed, notice_target: :start }, ':sunny:'
      it_behaves_like 'OK', { type: :next, notice_target: :next }, ':alarm_clock:'
      it_behaves_like 'OK', { type: :expired, notice_target: :next }, ':red_circle:'
      it_behaves_like 'OK', { type: :end_today, notice_target: :next }, ':cloud:'
      it_behaves_like 'OK', { type: :date_include, notice_target: :next }, ':cloud:' # <- sunny
      it_behaves_like 'OK', { type: :completed, notice_target: :next }, ':sunny:'
    end
    shared_examples_for '[確認待ち]担当者がいない/いる' do
      it_behaves_like 'OK', { type: :next, notice_target: :start }, ':alarm_clock:'
      it_behaves_like 'OK', { type: :expired, notice_target: :start }, ':red_circle:'
      it_behaves_like 'OK', { type: :end_today, notice_target: :start }, ':sunny:' # <- cloud
      it_behaves_like 'OK', { type: :date_include, notice_target: :start }, ':sunny:' # <- cloud
      it_behaves_like 'OK', { type: :completed, notice_target: :start }, ':sunny:'
      it_behaves_like 'OK', { type: :next, notice_target: :next }, ':alarm_clock:'
      it_behaves_like 'OK', { type: :expired, notice_target: :next }, ':red_circle:'
      it_behaves_like 'OK', { type: :end_today, notice_target: :next }, ':sunny:' # <- cloud
      it_behaves_like 'OK', { type: :date_include, notice_target: :next }, ':sunny:' # <- cloud
      it_behaves_like 'OK', { type: :completed, notice_target: :next }, ':sunny:'
    end
    shared_examples_for '[完了/対応不要]担当者がいない/いる' do
      it_behaves_like 'OK', { type: :next, notice_target: :start }, ':sunny:' # <- alarm_clock
      it_behaves_like 'OK', { type: :expired, notice_target: :start }, ':sunny:' # <- red_circle
      it_behaves_like 'OK', { type: :end_today, notice_target: :start }, ':sunny:'
      it_behaves_like 'OK', { type: :date_include, notice_target: :start }, ':sunny:'
      it_behaves_like 'OK', { type: :completed, notice_target: :start }, ':sunny:'
      it_behaves_like 'OK', { type: :next, notice_target: :next }, ':sunny:' # <- alarm_clock
      it_behaves_like 'OK', { type: :expired, notice_target: :next }, ':sunny:' # <- red_circle
      it_behaves_like 'OK', { type: :end_today, notice_target: :next }, ':sunny:'
      it_behaves_like 'OK', { type: :date_include, notice_target: :next }, ':sunny:'
      it_behaves_like 'OK', { type: :completed, notice_target: :next }, ':sunny:'
    end
    shared_examples_for '[完了/対応不要]担当者' do
      context '担当者がいない' do
        let_it_be(:task_event) { FactoryBot.create(:task_event, status:) }
        it_behaves_like '[完了/対応不要]担当者がいない/いる'
      end
      context '担当者がいる' do
        let_it_be(:task_event) { FactoryBot.create(:task_event, status:, assigned_user: user) }
        it_behaves_like '[完了/対応不要]担当者がいない/いる'
      end
    end

    context 'ステータスが未処理' do
      let_it_be(:status) { :untreated }
      it_behaves_like '[未処理/前提対応待ち/前提確認済み]担当者'
    end
    context 'ステータスが前提対応待ち' do
      let_it_be(:status) { :waiting_premise }
      it_behaves_like '[未処理/前提対応待ち/前提確認済み]担当者'
    end
    context 'ステータスが前提確認済み' do
      let_it_be(:status) { :confirmed_premise }
      it_behaves_like '[未処理/前提対応待ち/前提確認済み]担当者'
    end
    context 'ステータスが処理中' do
      let_it_be(:status) { :processing }
      context '担当者がいない' do
        let_it_be(:task_event) { FactoryBot.create(:task_event, status:) }
        it_behaves_like '[処理中]担当者がいない/いる'
      end
      context '担当者がいる' do
        let_it_be(:task_event) { FactoryBot.create(:task_event, status:, assigned_user: user) }
        it_behaves_like '[処理中]担当者がいない/いる'
      end
    end
    context 'ステータスが保留' do
      let_it_be(:status) { :pending }
      context '担当者がいない' do
        let_it_be(:task_event) { FactoryBot.create(:task_event, status:) }
        it_behaves_like '[保留]担当者がいない/いる'
      end
      context '担当者がいる' do
        let_it_be(:task_event) { FactoryBot.create(:task_event, status:, assigned_user: user) }
        it_behaves_like '[保留]担当者がいない/いる'
      end
    end
    context 'ステータスが確認待ち' do
      let_it_be(:status) { :waiting_confirm }
      context '担当者がいない' do
        let_it_be(:task_event) { FactoryBot.create(:task_event, status:) }
        it_behaves_like '[確認待ち]担当者がいない/いる'
      end
      context '担当者がいる' do
        let_it_be(:task_event) { FactoryBot.create(:task_event, status:, assigned_user: user) }
        it_behaves_like '[確認待ち]担当者がいない/いる'
      end
    end
    context 'ステータスが完了' do
      let_it_be(:status) { :complete }
      context '担当者がいない' do
        let_it_be(:task_event) { FactoryBot.create(:task_event, status:) }
        it_behaves_like '[完了/対応不要]担当者がいない/いる'
      end
      context '担当者がいる' do
        let_it_be(:task_event) { FactoryBot.create(:task_event, status:, assigned_user: user) }
        it_behaves_like '[完了/対応不要]担当者がいない/いる'
      end
    end
    context 'ステータスが対応不要' do
      let_it_be(:status) { :unnecessary }
      it_behaves_like '[完了/対応不要]担当者'
    end
  end
end
