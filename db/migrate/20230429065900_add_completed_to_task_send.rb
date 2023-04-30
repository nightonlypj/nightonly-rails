class AddCompletedToTaskSend < ActiveRecord::Migration[6.1]
  def change
    add_column :task_events, :last_completed_at, :datetime, comment: '最終完了日時'
    add_index :task_events, [:space_id, :status, :last_completed_at], name: 'index_task_events5'

    add_column :send_settings, :start_notice_completed, :boolean, null: false, default: true, comment: '[開始確認]完了通知'
    add_column :send_settings, :next_notice_completed,  :boolean, null: false, default: true, comment: '[翌営業日・終了確認]完了通知'

    add_column :send_histories, :completed_task_event_ids, :text, comment: '完了したタスクイベントIDs'
  end
end
