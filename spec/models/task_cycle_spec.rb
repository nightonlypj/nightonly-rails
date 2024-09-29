require 'rails_helper'

RSpec.describe TaskCycle, type: :model do
  # 周期
  # テストパターン
  #   ない, 毎週, 毎月, 毎年
  describe 'validates :cycle' do
    # テストケース
    context 'ない' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, cycle: nil) }
      let(:messages) { { cycle: [get_locale('activerecord.errors.models.task_cycle.attributes.cycle.blank')] } }
      it_behaves_like 'InValid'
    end
    context '毎週' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, :weekly) }
      it_behaves_like 'Valid'
    end
    context '毎月' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, :monthly, :day) }
      it_behaves_like 'Valid'
    end
    context '毎年' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, :yearly, :day) }
      it_behaves_like 'Valid'
    end
  end

  # 月
  # テストパターン
  #   周期: 毎週, 毎月, 毎年
  #   月: ない, 0, 1, 12, 13
  describe 'validates :month' do
    # テストケース
    context '周期が毎週' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, :weekly, month: nil) }
      it_behaves_like 'Valid'
    end
    context '周期が毎月' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, :monthly, :day, month: nil) }
      it_behaves_like 'Valid'
    end
    context '周期が毎年' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, :yearly, :day, month:) }
      context '月がない' do
        let(:month) { nil }
        let(:messages) { { month: [get_locale('activerecord.errors.models.task_cycle.attributes.month.blank')] } }
        it_behaves_like 'InValid'
      end
      context '月が0' do
        let(:month) { 0 }
        let(:messages) { { month: [get_locale('activerecord.errors.models.task_cycle.attributes.month.greater_than_or_equal_to', count: 1)] } }
        it_behaves_like 'InValid'
      end
      context '月が1' do
        let(:month) { 1 }
        it_behaves_like 'Valid'
      end
      context '月が12' do
        let(:month) { 12 }
        it_behaves_like 'Valid'
      end
      context '月が13' do
        let(:month) { 13 }
        let(:messages) { { month: [get_locale('activerecord.errors.models.task_cycle.attributes.month.less_than_or_equal_to', count: 12)] } }
        it_behaves_like 'InValid'
      end
    end
  end

  # 対象
  # テストパターン
  #   周期: 毎週, 毎月, 毎年
  #   対象: ない, 日, 営業日, 週
  describe 'validates :target' do
    # テストケース
    shared_examples_for '[毎月/毎年]' do
      context '対象がない' do
        subject(:model) { FactoryBot.build_stubbed(:task_cycle, cycle, :day, target: nil) }
        let(:messages) { { target: [get_locale('activerecord.errors.models.task_cycle.attributes.target.blank')] } }
        it_behaves_like 'InValid'
      end
      context '対象が日' do
        subject(:model) { FactoryBot.build_stubbed(:task_cycle, cycle, :day) }
        it_behaves_like 'Valid'
      end
      context '対象が営業日' do
        subject(:model) { FactoryBot.build_stubbed(:task_cycle, cycle, :business_day) }
        it_behaves_like 'Valid'
      end
      context '対象が週' do
        subject(:model) { FactoryBot.build_stubbed(:task_cycle, cycle, :week) }
        it_behaves_like 'Valid'
      end
    end

    context '周期が毎週' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, :weekly, target: nil) }
      it_behaves_like 'Valid'
    end
    context '周期が毎月' do
      let(:cycle) { :monthly }
      it_behaves_like '[毎月/毎年]'
    end
    context '周期が毎年' do
      let(:cycle) { :yearly }
      it_behaves_like '[毎月/毎年]'
    end
  end

  # 日
  # テストパターン
  #   周期: 毎週, 毎月, 毎年
  #   対象: 日, 営業日, 週
  #   日: ない, 0, 1, 31, 32
  describe 'validates :day' do
    # テストケース
    shared_examples_for '[毎月/毎年]' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, cycle, target, day:) }
      context '対象が日' do
        let(:target) { :day }
        context '日がない' do
          let(:day) { nil }
          let(:messages) { { day: [get_locale('activerecord.errors.models.task_cycle.attributes.day.blank')] } }
          it_behaves_like 'InValid'
        end
        context '日が0' do
          let(:day) { 0 }
          let(:messages) { { day: [get_locale('activerecord.errors.models.task_cycle.attributes.day.greater_than_or_equal_to', count: 1)] } }
          it_behaves_like 'InValid'
        end
        context '日が1' do
          let(:day) { 1 }
          it_behaves_like 'Valid'
        end
        context '日が31' do
          let(:day) { 31 }
          it_behaves_like 'Valid'
        end
        context '日が32' do
          let(:day) { 32 }
          let(:messages) { { day: [get_locale('activerecord.errors.models.task_cycle.attributes.day.less_than_or_equal_to', count: 31)] } }
          it_behaves_like 'InValid'
        end
      end
      context '対象が営業日' do
        let(:target) { :business_day }
        let(:day) { nil }
        it_behaves_like 'Valid'
      end
      context '対象が週' do
        let(:target) { :week }
        let(:day) { nil }
        it_behaves_like 'Valid'
      end
    end

    context '周期が毎週' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, :weekly, day: nil) }
      it_behaves_like 'Valid'
    end
    context '周期が毎月' do
      let(:cycle) { :monthly }
      it_behaves_like '[毎月/毎年]'
    end
    context '周期が毎年' do
      let(:cycle) { :yearly }
      it_behaves_like '[毎月/毎年]'
    end
  end

  # 営業日
  # テストパターン
  #   周期: 毎週, 毎月, 毎年
  #   対象: 日, 営業日, 週
  #   営業日: ない, 0, 1, 31, 32
  describe 'validates :business_day' do
    # テストケース
    shared_examples_for '[毎月/毎年]' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, cycle, target, business_day:) }
      context '対象が日' do
        let(:target) { :day }
        let(:business_day) { nil }
        it_behaves_like 'Valid'
      end
      context '対象が営業日' do
        let(:target) { :business_day }
        context '営業日がない' do
          let(:business_day) { nil }
          let(:messages) { { business_day: [get_locale('activerecord.errors.models.task_cycle.attributes.business_day.blank')] } }
          it_behaves_like 'InValid'
        end
        context '営業日が0' do
          let(:business_day) { 0 }
          let(:messages) { { business_day: [get_locale('activerecord.errors.models.task_cycle.attributes.business_day.greater_than_or_equal_to', count: 1)] } }
          it_behaves_like 'InValid'
        end
        context '営業日が1' do
          let(:business_day) { 1 }
          it_behaves_like 'Valid'
        end
        context '営業日が31' do
          let(:business_day) { 31 }
          it_behaves_like 'Valid'
        end
        context '営業日が32' do
          let(:business_day) { 32 }
          let(:messages) { { business_day: [get_locale('activerecord.errors.models.task_cycle.attributes.business_day.less_than_or_equal_to', count: 31)] } }
          it_behaves_like 'InValid'
        end
      end
      context '対象が週' do
        let(:target) { :week }
        let(:business_day) { nil }
        it_behaves_like 'Valid'
      end
    end

    context '周期が毎週' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, :weekly, business_day: nil) }
      it_behaves_like 'Valid'
    end
    context '周期が毎月' do
      let(:cycle) { :monthly }
      it_behaves_like '[毎月/毎年]'
    end
    context '周期が毎年' do
      let(:cycle) { :yearly }
      it_behaves_like '[毎月/毎年]'
    end
  end

  # 週
  # テストパターン
  #   周期: 毎週, 毎月, 毎年
  #   対象: 日, 営業日, 週
  #   週: ない, 第1, 最終
  describe 'validates :week' do
    # テストケース
    shared_examples_for '[毎月/毎年]' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, cycle, target, week:) }
      context '対象が日' do
        let(:target) { :day }
        let(:week) { nil }
        it_behaves_like 'Valid'
      end
      context '対象が営業日' do
        let(:target) { :business_day }
        let(:week) { nil }
        it_behaves_like 'Valid'
      end
      context '対象が週' do
        let(:target) { :week }
        context '週がない' do
          let(:week) { nil }
          let(:messages) { { week: [get_locale('activerecord.errors.models.task_cycle.attributes.week.blank')] } }
          it_behaves_like 'InValid'
        end
        context '週が第1' do
          let(:week) { :first }
          it_behaves_like 'Valid'
        end
        context '週が最終' do
          let(:week) { :last }
          it_behaves_like 'Valid'
        end
      end
    end

    context '周期が毎週' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, :weekly, week: nil) }
      it_behaves_like 'Valid'
    end
    context '周期が毎月' do
      let(:cycle) { :monthly }
      it_behaves_like '[毎月/毎年]'
    end
    context '周期が毎年' do
      let(:cycle) { :yearly }
      it_behaves_like '[毎月/毎年]'
    end
  end

  # 曜日
  # テストパターン
  #   周期: 毎週, 毎月, 毎年
  #   対象: 日, 営業日, 週
  #   曜日: ない, 月曜日, 金曜日
  describe 'validates :wday' do
    # テストケース
    shared_examples_for '曜日' do
      context 'ない' do
        let(:wday) { nil }
        let(:messages) { { wday: [get_locale('activerecord.errors.models.task_cycle.attributes.wday.blank')] } }
        it_behaves_like 'InValid'
      end
      context '月曜日' do
        let(:wday) { :mon }
        it_behaves_like 'Valid'
      end
      context '金曜日' do
        let(:wday) { :fri }
        it_behaves_like 'Valid'
      end
    end

    shared_examples_for '[毎月/毎年]' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, cycle, target, wday:) }
      context '対象が日' do
        let(:target) { :day }
        let(:wday) { nil }
        it_behaves_like 'Valid'
      end
      context '対象が営業日' do
        let(:target) { :business_day }
        let(:wday) { nil }
        it_behaves_like 'Valid'
      end
      context '対象が週' do
        let(:target) { :week }
        it_behaves_like '曜日'
      end
    end

    context '周期が毎週' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, :weekly, wday:) }
      it_behaves_like '曜日'
    end
    context '周期が毎月' do
      let(:cycle) { :monthly }
      it_behaves_like '[毎月/毎年]'
    end
    context '周期が毎年' do
      let(:cycle) { :yearly }
      it_behaves_like '[毎月/毎年]'
    end
  end

  # 休日の場合
  # テストパターン
  #   周期: 毎週, 毎月, 毎年
  #   対象: 日, 営業日, 週
  #   休日の場合: ない, 前日, 当日, 翌日
  describe 'validates :handling_holiday' do
    # テストケース
    shared_examples_for '休日の場合' do
      context 'ない' do
        let(:handling_holiday) { nil }
        let(:messages) { { handling_holiday: [get_locale('activerecord.errors.models.task_cycle.attributes.handling_holiday.blank')] } }
        it_behaves_like 'InValid'
      end
      context '前日' do
        let(:handling_holiday) { :before }
        it_behaves_like 'Valid'
      end
      context '当日' do
        let(:handling_holiday) { :onday }
        it_behaves_like 'Valid'
      end
      context '翌日' do
        let(:handling_holiday) { :after }
        it_behaves_like 'Valid'
      end
    end

    shared_examples_for '[毎月/毎年]' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, cycle, target, handling_holiday:) }
      context '対象が日' do
        let(:target) { :day }
        it_behaves_like '休日の場合'
      end
      context '対象が営業日' do
        let(:target) { :business_day }
        let(:handling_holiday) { nil }
        it_behaves_like 'Valid'
      end
      context '対象が週' do
        let(:target) { :week }
        it_behaves_like '休日の場合'
      end
    end

    context '周期が毎週' do
      subject(:model) { FactoryBot.build_stubbed(:task_cycle, :weekly, handling_holiday:) }
      it_behaves_like '休日の場合'
    end
    context '周期が毎月' do
      let(:cycle) { :monthly }
      it_behaves_like '[毎月/毎年]'
    end
    context '周期が毎年' do
      let(:cycle) { :yearly }
      it_behaves_like '[毎月/毎年]'
    end
  end

  # 期間（日）
  # テストパターン
  #   ない, 0, 1, 20, 21
  describe 'validates :period' do
    subject(:model) { FactoryBot.build_stubbed(:task_cycle, period:) }

    # テストケース
    context 'ない' do
      let(:period) { nil }
      let(:messages) { { period: [get_locale('activerecord.errors.models.task_cycle.attributes.period.blank')] } }
      it_behaves_like 'InValid'
    end
    context '0' do
      let(:period) { 0 }
      let(:messages) { { period: [get_locale('activerecord.errors.models.task_cycle.attributes.period.greater_than_or_equal_to', count: 1)] } }
      it_behaves_like 'InValid'
    end
    context '1' do
      let(:period) { 1 }
      it_behaves_like 'Valid'
    end
    context '20' do
      let(:period) { 20 }
      it_behaves_like 'Valid'
    end
    context '21' do
      let(:period) { 21 }
      let(:messages) { { period: [get_locale('activerecord.errors.models.task_cycle.attributes.period.less_than_or_equal_to', count: 20)] } }
      it_behaves_like 'InValid'
    end
  end

  # 休日含む
  # テストパターン
  #   ない, true, false, 文字
  describe 'validates :holiday' do
    subject(:model) { FactoryBot.build_stubbed(:task_cycle, holiday:) }

    # テストケース
    context 'ない' do
      let(:holiday) { nil }
      let(:messages) { { holiday: [get_locale('activerecord.errors.models.task_cycle.attributes.holiday.inclusion')] } }
      it_behaves_like 'InValid'
    end
    context 'true' do
      let(:holiday) { true }
      it_behaves_like 'Valid'
    end
    context 'false' do
      let(:holiday) { false }
      it_behaves_like 'Valid'
    end
    context '文字' do
      let(:holiday) { 'a' }
      it_behaves_like 'Valid' # NOTE: trueになる
    end
  end
end
