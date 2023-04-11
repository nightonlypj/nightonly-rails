class CreateTaskSendSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :task_send_settings, comment: 'タスク通知設定' do |t|
      t.references :space, null: false, type: :bigint, foreign_key: true, comment: 'スペースID'

      t.boolean :slack_enabled, null: false, default: false, comment: '[Slack]通知する'
      t.string  :slack_webhook_url,                          comment: '[Slack]Webhook URL'
      t.string  :slack_mention,                              comment: '[Slack]メンション'

      t.boolean :email_enabled, null: false, default: false, comment: '[メール]通知する'
      t.string  :email_address,                              comment: '[メール]アドレス'

      t.integer :today_notice_start_hour,                             comment: '[当日通知]開始時間'
      t.boolean :today_notice_required,  null: false, default: false, comment: '[当日通知]必須'

      t.integer :next_notice_start_hour,                            comment: '[事前通知]開始時間'
      t.boolean :next_notice_required, null: false, default: false, comment: '[事前通知]必須'

      t.references :last_updated_user,         type: :bigint, foreign_key: false, comment: '最終更新者ID'
      t.datetime :deleted_at, comment: '削除日時'
      t.timestamps
    end
    add_index :task_send_settings, [:space_id, :deleted_at, :id], name: 'task_send_settings1'
    add_index :task_send_settings, [:updated_at, :id],            name: 'task_send_settings2'
    add_index :task_send_settings, [:deleted_at, :id],            name: 'task_send_settings3'
  end
end
