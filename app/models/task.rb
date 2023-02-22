class Task < ApplicationRecord
  belongs_to :space
  belongs_to :created_user,      class_name: 'User', optional: true # NOTE: アカウント削除済みでも変更できるようにoptionalを追加
  belongs_to :last_updated_user, class_name: 'User', optional: true
  has_many :task_cycles, dependent: :destroy

  # 優先度
  enum priority: {
    none: 0,   # (なし)
    high: 1,   # 高
    middle: 2, # 中
    low: 3     # 低
  }, _prefix: true
end
