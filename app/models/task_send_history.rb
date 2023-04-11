class TaskSendHistory < ApplicationRecord
  belongs_to :space
  belongs_to :task_send_setting

  # 通知対象
  enum notice_target: {
    today: 1, # 当日
    next: 2   # 事前
  }, _prefix: true

  # 送信対象
  enum send_target: {
    slack: 1, # Slack
    email: 2  # メール
  }, _prefix: true

  # 送信結果
  enum send_result: {
    success: 1, # 成功
    failure: 2  # 失敗
  }, _prefix: true
end
