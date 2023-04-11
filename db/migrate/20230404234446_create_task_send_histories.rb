class CreateTaskSendHistories < ActiveRecord::Migration[6.1]
  def change
    create_table :task_send_histories, comment: 'タスク通知履歴' do |t|
      t.references :space,             null: false, type: :bigint, foreign_key: true, comment: 'スペースID'
      t.references :task_send_setting, null: false, type: :bigint, foreign_key: true, comment: 'タスク通知設定ID'

      t.integer  :notice_target, null: false, comment: '通知対象'
      t.integer  :send_target,   null: false, comment: '送信対象'
      t.date     :target_date,   null: false, comment: '対象日'

      t.datetime :sended_at,     null: false, comment: '送信日時'
      t.integer  :send_result,   null: false, comment: '送信結果'

      t.text :error_message, comment: 'エラーメッセージ'
      t.text :sended_data,   comment: '送信データ'
  
      t.text :next_task_event_ids,         comment: '翌営業日開始のタスクイベントIDs'
      t.text :expired_task_event_ids,      comment: '期限切れのタスクイベントIDs'
      t.text :end_today_task_event_ids,    comment: '本日までのタスクイベントIDs'
      t.text :date_include_task_event_ids, comment: '期間内のタスクイベントIDs'

      t.timestamps
    end
    add_index :task_send_histories, [:space_id, :notice_target, :target_date, :id], name: 'task_send_histories1'
    add_index :task_send_histories, [:target_date, :sended_at, :id],                name: 'task_send_histories2'
  end
end
