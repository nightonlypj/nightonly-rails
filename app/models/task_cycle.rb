class TaskCycle < ApplicationRecord
  belongs_to :space
  belongs_to :task

  validates :cycle, presence: true
  validates :month, presence: true, if: proc { |task_cycle| task_cycle.cycle_yearly? }
  validates :month, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }, if: proc { |task_cycle| task_cycle.month.present? }
  validates :target, presence: true, if: proc { |task_cycle| task_cycle.cycle_monthly_or_yearly? }
  validates :day, presence: true, if: proc { |task_cycle| task_cycle.cycle_monthly_or_yearly? && task_cycle.target_day? }
  validates :day, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }, if: proc { |task_cycle| task_cycle.day.present? && errors[:day].blank? }
  validates :business_day, presence: true, if: proc { |task_cycle| task_cycle.cycle_monthly_or_yearly? && task_cycle.target_business_day? }
  validates :business_day, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }, if: proc { |task_cycle| task_cycle.business_day.present? && errors[:business_day].blank? }
  validates :week, presence: true, if: proc { |task_cycle| task_cycle.cycle_monthly_or_yearly? && task_cycle.target_week? }
  validates :wday, presence: true, if: proc { |task_cycle| task_cycle.cycle_weekly? || (task_cycle.cycle_monthly_or_yearly? && task_cycle.target_week?) }
  validates :handling_holiday, presence: true, if: proc { |task_cycle| task_cycle.cycle_weekly? || (task_cycle.cycle_monthly_or_yearly? && task_cycle.target_day_or_week?) }
  validates :period, presence: true
  validates :period, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }, if: proc { errors[:period].blank? }

  scope :active, -> { where(deleted_at: nil) }
  scope :by_month, lambda { |months|
    return none if months.count.zero?
    return if months.include?(nil) && months.compact.uniq.sort == [*1..12]

    where(month: months)
  }
  scope :by_task_period, lambda { |start_date, end_date|
    where('tasks.started_date <= ? AND (tasks.ended_date IS NULL OR tasks.ended_date >= ?)', end_date, start_date)
  }

  # 周期
  enum cycle: {
    weekly: 1,  # 毎週
    monthly: 2, # 毎月
    yearly: 3   # 毎年
  }, _prefix: true

  # 対象
  enum target: {
    day: 1,          # 日
    business_day: 2, # 営業日
    week: 3          # 週
  }, _prefix: true

  # 週
  enum week: {
    first: 1,  # 第1
    second: 2, # 第2
    third: 3,  # 第3
    fourth: 4, # 第4
    last: 5    # 最終
  }, _prefix: true

  # 曜日
  enum wday: {
    # sun: 0, # 日曜日
    mon: 1, # 月曜日
    tue: 2, # 火曜日
    wed: 3, # 水曜日
    thu: 4, # 木曜日
    fri: 5 # 金曜日
    # sat: 6  # 土曜日
  }, _prefix: true

  # 休日の扱い
  enum handling_holiday: {
    before: -1, # 前日
    after: 1    # 翌日
  }, _prefix: true

  def cycle_monthly_or_yearly?
    %i[monthly yearly].include?(cycle&.to_sym)
  end

  def target_day_or_week?
    %i[day week].include?(target&.to_sym)
  end
end
