class CreateTaskEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :task_events, comment: 'タスクイベント' do |t|
      t.string :code, null: false, comment: 'コード'

      t.references :space,      null: false, type: :bigint, foreign_key: true, comment: 'スペースID'
      t.references :task_cycle, null: false, type: :bigint, foreign_key: true, comment: 'タスク周期ID'

      t.date :started_date, null: false, comment: '開始日'
      t.date :ended_date,   null: false, comment: '終了日'

      t.integer :status, null: false, default: 0, comment: 'ステータス'

      t.references :assigned_user, type: :bigint, foreign_key: false, comment: '担当者ID'
      t.datetime   :assigned_at, comment: '担当日時'

      t.text :memo, comment: 'メモ'

      t.references :last_updated_user, type: :bigint, foreign_key: false, comment: '最終更新者ID'
      t.timestamps
    end
    add_index :task_events, :code, unique: true,                        name: 'index_task_events1'
    add_index :task_events, %i[task_cycle_id ended_date], unique: true, name: 'index_task_events2'
    add_index :task_events, %i[space_id started_date ended_date id],    name: 'index_task_events3'
    add_index :task_events, %i[space_id status id],                     name: 'index_task_events4'
  end
end
