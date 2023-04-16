class CreateSendSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :send_settings, comment: '通知設定' do |t|
      t.references :space, null: false, type: :bigint, foreign_key: true, comment: 'スペースID'
      t.references :slack_domain,       type: :bigint, foreign_key: true, comment: 'SlackドメインID'

      t.boolean :slack_enabled, null: false, default: false, comment: '[Slack]通知する'
      t.string  :slack_webhook_url,                          comment: '[Slack]Webhook URL'
      t.string  :slack_mention,                              comment: '[Slack]メンション'

      t.boolean :email_enabled, null: false, default: false, comment: '[メール]通知する'
      t.string  :email_address,                              comment: '[メール]アドレス'

      t.integer :start_notice_start_hour,                             comment: '[開始確認]開始時間'
      t.boolean :start_notice_required,  null: false, default: false, comment: '[開始確認]必須'

      t.integer :next_notice_start_hour,                            comment: '[翌営業日・終了確認]開始時間'
      t.boolean :next_notice_required, null: false, default: false, comment: '[翌営業日・終了確認]必須'

      t.references :last_updated_user, type: :bigint, foreign_key: false, comment: '最終更新者ID'
      t.datetime :deleted_at, comment: '削除日時'
      t.timestamps
    end
    add_index :send_settings, [:space_id, :deleted_at, :id], name: 'send_settings1'
    add_index :send_settings, [:updated_at, :id],            name: 'send_settings2'
    add_index :send_settings, [:deleted_at, :id],            name: 'send_settings3'
  end
end
