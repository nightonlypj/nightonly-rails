class CreateTaskEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :task_events do |t|
      t.references :space,      null: false, type: :bigint, foreign_key: true, comment: 'スペースID' # NOTE: indexの為
      t.references :task_cycle, null: false, type: :bigint, foreign_key: true, comment: 'タスク周期ID'

      t.date :started_date, null: false, comment: '開始日'
      t.date :ended_date,   null: false, comment: '終了日'

      t.integer :status, null: false, default: 0, comment: 'ステータス'
      t.text    :memo, comment: 'メモ'

      t.references :assigned_user, type: :bigint, foreign_key: false, comment: '担当者ID'
      t.datetime   :assigned_at, comment: '担当日時'

      t.timestamps
    end
    add_index :task_events, [:task_cycle_id, :ended_date], unique: true, name: 'index_task_events1'
  end
end
