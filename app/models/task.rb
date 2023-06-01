class Task < ApplicationRecord
  belongs_to :space
  belongs_to :created_user,      class_name: 'User', optional: true # NOTE: アカウント削除済みでも変更できるようにoptionalを追加
  belongs_to :last_updated_user, class_name: 'User', optional: true
  has_many :task_cycles, dependent: :destroy
  has_many :task_cycles_active, -> { where(deleted_at: nil) }, class_name: 'TaskCycle'
  has_many :task_cycles_inactive, -> { where.not(deleted_at: nil) }, class_name: 'TaskCycle'

  validates :priority, presence: true
  validates :title, presence: true
  validates :title, length: { maximum: Settings.task_title_maximum }, allow_blank: true
  validates :summary, length: { maximum: Settings.task_summary_maximum }, allow_blank: true
  validates :premise, length: { maximum: Settings.task_premise_maximum }, allow_blank: true
  validates :process, length: { maximum: Settings.task_process_maximum }, allow_blank: true
  validates :started_date, presence: true
  validate :validate_started_date
  validate :validate_ended_date

  scope :search, lambda { |text|
    return if text&.strip.blank?

    sql = "tasks.title #{search_like} ?"

    task = all
    text.split(/[[:blank:]]+/).each do |word|
      value = "%#{word}%"
      task = task.where(sql, value)
    end

    task
  }
  scope :by_priority, lambda { |priorities|
    return none if priorities.count == 0
    return if priorities.count >= Task.priorities.count

    where(priority: priorities)
  }
  scope :by_start_end_date, lambda { |before, active, after|
    return none if !before && !active && !after
    return if before && active && after

    task = none
    task = task.or(where(started_date: (Time.current.to_date + 1.day)..)) if before
    task = task.or(where('started_date <= ? AND (ended_date IS NULL OR ended_date >= ?)', Time.current.to_date, Time.current.to_date)) if active
    task = task.or(where(ended_date: ..(Time.current.to_date - 1.day))) if after

    task
  }

  # 優先度
  enum priority: {
    high: 1,   # 高
    middle: 2, # 中
    low: 3,    # 低
    none: 9    # 未設定
  }, _prefix: true

  # 最終更新日時
  def last_updated_at
    updated_at == created_at ? nil : updated_at
  end

  private

  def validate_started_date
    return if started_date.blank? || (id.present? && !started_date_changed?)

    errors.add(:started_date, :before) if started_date < Time.current.to_date
  end

  def validate_ended_date
    return if started_date.blank? || ended_date.blank?

    errors.add(:ended_date, :after) if ended_date < started_date
  end
end
