class TaskSendHistory < ApplicationRecord
  belongs_to :space
  belongs_to :task_send_setting

  # 送信結果
  enum send_result: {
    success: 1, # 成功
    failure: 2  # 失敗
  }, _prefix: true

  # 送信対象
  enum send_target: {
    slack: 1, # Slack
    email: 2  # メール
  }, _prefix: true

  # 通知対象
  enum notice_target: {
    before: 1, # 事前
    today: 2   # 当日
  }, _prefix: true
end
