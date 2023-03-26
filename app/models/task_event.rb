class TaskEvent < ApplicationRecord
  belongs_to :space
  belongs_to :task_cycle
  belongs_to :assigned_user, class_name: 'User', optional: true # NOTE: アカウント削除済みでも変更できるようにoptionalを追加

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
end
