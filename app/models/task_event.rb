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

  scope :by_month, lambda { |months, last_date|
    return none if months.count.zero?

    task_event = all
    index = 0
    while index < months.count
      start_date = "#{months[index]}01".to_date
      break if start_date > last_date

      while index + 1 < months.count
        end_date = "#{months[index + 1]}01".to_date
        break if start_date + 1.month != end_date || end_date.end_of_month >= last_date

        index += 1
      end
      if index + 1 < months.count
        end_date = end_date.end_of_month
        index += 1
      else
        end_date = start_date.end_of_month
      end
      if end_date >= last_date
        task_event = task_event.where(ended_date: start_date..last_date)
        break
      end

      task_event = task_event.where(ended_date: start_date..end_date)
      index += 1
    end

    task_event
  }

  # ステータス
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
end
