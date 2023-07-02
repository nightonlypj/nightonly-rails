class CreateSendHistories < ActiveRecord::Migration[6.1]
  def change
    create_table :send_histories, comment: '通知履歴' do |t|
      t.references :space,        null: false, type: :bigint, foreign_key: true, comment: 'スペースID'
      t.references :send_setting, null: false, type: :bigint, foreign_key: true, comment: '通知設定ID'

      t.date    :target_date,   null: false, comment: '対象日'
      t.integer :notice_target, null: false, comment: '通知対象'
      t.integer :send_target,   null: false, comment: '送信対象'

      t.integer  :status,     null: false, default: 0, comment: 'ステータス'
      t.datetime :started_at, null: false,             comment: '開始日時'
      t.datetime :completed_at,                        comment: '完了日時'
      t.integer  :target_count, null: false,           comment: '対象件数'

      t.text :next_task_event_ids,         comment: '翌営業日開始のタスクイベントIDs'
      t.text :expired_task_event_ids,      comment: '期限切れのタスクイベントIDs'
      t.text :end_today_task_event_ids,    comment: '本日までのタスクイベントIDs'
      t.text :date_include_task_event_ids, comment: '期間内のタスクイベントIDs'

      t.text :error_message, comment: 'エラーメッセージ'
      t.text :send_data,     comment: '送信データ'

      t.timestamps
    end
    add_index :send_histories, [:space_id, :target_date, :notice_target], name: 'send_histories1'
    add_index :send_histories, [:target_date, :completed_at, :id],        name: 'send_histories2'
  end
end
