class SendHistory < ApplicationRecord
  belongs_to :space
  belongs_to :send_setting

  # 通知対象
  enum :notice_target, {
    start: 1, # 開始確認
    next: 2   # 翌営業日・終了確認
  }, prefix: true

  # 送信対象
  enum :send_target, {
    slack: 1, # Slack
    email: 2  # メール
  }, prefix: true

  # ステータス
  enum :status, {
    waiting: 0,    # 処理待ち
    processing: 1, # 処理中 # NOTE: 現状、未使用
    success: 7,    # 成功
    skip: 8,       # スキップ
    failure: 9     # 失敗
  }, prefix: true
end
