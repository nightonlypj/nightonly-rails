class TaskCycle < ApplicationRecord
  belongs_to :space
  belongs_to :task
  has_many :task_events, dependent: :destroy

  validates :cycle, presence: true
  validates :month, presence: true, if: -> { cycle_yearly? }
  validates :month, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }, allow_blank: true
  validates :target, presence: true, if: -> { cycle_monthly_or_yearly? }
  validates :day, presence: true, if: -> { cycle_monthly_or_yearly? && target_day? }
  validates :day, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }, allow_blank: true
  validates :business_day, presence: true, if: -> { cycle_monthly_or_yearly? && target_business_day? }
  validates :business_day, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }, allow_blank: true
  validates :week, presence: true, if: -> { cycle_monthly_or_yearly? && target_week? }
  validates :wday, presence: true, if: -> { cycle_weekly? || (cycle_monthly_or_yearly? && target_week?) }
  validates :handling_holiday, presence: true, if: -> { cycle_weekly? || (cycle_monthly_or_yearly? && target_day_or_week?) }
  validates :period, presence: true
  validates :period, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 20 }, allow_blank: true
  validates :holiday, inclusion: { in: [true, false] } # NOTE: presenceだとfalseもエラーになる為

  scope :active, -> { where(deleted_at: nil) }
  scope :by_month, ->(months) {
    return none if months.none?
    return if months.include?(nil) && months.compact.uniq.sort == [*1..12]

    where(month: months)
  }
  scope :by_task_period, ->(start_date, end_date) {
    where('tasks.started_date <= ? AND (tasks.ended_date IS NULL OR tasks.ended_date >= ?)', end_date, start_date)
  }

  # 周期
  enum :cycle, {
    weekly: 1,  # 毎週
    monthly: 2, # 毎月
    yearly: 3   # 毎年
  }, prefix: true

  # 対象
  enum :target, {
    day: 1,          # 日
    business_day: 2, # 営業日
    week: 3          # 週
  }, prefix: true

  # 週
  enum :week, {
    first: 1,  # 第1
    second: 2, # 第2
    third: 3,  # 第3
    fourth: 4, # 第4
    last: 5    # 最終
  }, prefix: true

  # 曜日
  enum :wday, {
    sun: 0, # 日曜日
    mon: 1, # 月曜日
    tue: 2, # 火曜日
    wed: 3, # 水曜日
    thu: 4, # 木曜日
    fri: 5, # 金曜日
    sat: 6  # 土曜日
  }, prefix: true

  # 休日の場合
  enum :handling_holiday, {
    before: -1, # 前日
    onday: 0,   # 当日
    after: 1    # 翌日
  }, prefix: true

  def cycle_monthly_or_yearly?
    %i[monthly yearly].include?(cycle&.to_sym)
  end

  def target_day_or_week?
    %i[day week].include?(target&.to_sym)
  end
end
