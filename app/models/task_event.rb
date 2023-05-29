class TaskEvent < ApplicationRecord
  attr_accessor :assign_myself, :assign_delete

  belongs_to :space
  belongs_to :task_cycle
  belongs_to :assigned_user, class_name: 'User', optional: true # NOTE: アカウント削除済みでも変更できるようにoptionalを追加
  belongs_to :last_updated_user, class_name: 'User', optional: true

  validates :code, presence: true
  validates :code, uniqueness: { case_sensitive: true }, allow_blank: true
  validates :status, presence: true
  validates :memo, length: { maximum: Settings.task_event_memo_maximum }, allow_blank: true
  validates :last_ended_date, presence: true
  validate :validate_last_ended_date

  scope :by_month, lambda { |months| # NOTE: monthsの形式が正しく、昇順の前提
    task_event = none
    index = 0
    while index < months.count
      start_month = "#{months[index]}01".to_date
      end_month = start_month

      while index + 1 < months.count
        next_start_month = "#{months[index + 1]}01".to_date
        break if next_start_month != end_month + 1.month

        end_month = next_start_month
        index += 1
      end

      task_event = task_event.or(where(started_date: start_month..end_month.end_of_month))
      index += 1
    end

    task_event
  }

  # ステータス
  NOT_NOTICE_STATUS = %i[complete unnecessary].freeze
  enum status: {
    untreated: 0,         # 未処理
    waiting_premise: 1,   # 前提対応待ち
    confirmed_premise: 2, # 前提確認済み
    processing: 4,        # 処理中
    pending: 5,           # 保留
    waiting_confirm: 7,   # 確認待ち
    complete: 8,          # 完了
    unnecessary: 9        # 対応不要
  }, _prefix: true

  # 最終更新日時
  def last_updated_at
    updated_at == created_at ? nil : updated_at
  end

  private

  def validate_last_ended_date
    return if started_date.blank? || last_ended_date.blank?

    return errors.add(:last_ended_date, :after) if last_ended_date < started_date
    return errors.add(:last_ended_date, :before) if last_ended_date > (started_date + 1.month).end_of_month
  end
end
