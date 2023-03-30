class CreateTaskCycles < ActiveRecord::Migration[6.1]
  def change
    create_table :task_cycles, comment: 'タスク周期' do |t|
      t.references :space, null: false, type: :bigint, foreign_key: true, comment: 'スペースID'
      t.references :task,  null: false, type: :bigint, foreign_key: true, comment: 'タスクID'

      t.integer :cycle, null: false, comment: '周期'
      t.integer :month, comment: '月' # 毎年

      t.integer :target,       comment: '対象'  # 毎月/毎年
      t.integer :day,          comment: '日'    # 毎月/毎年(日)
      t.integer :business_day, comment: '営業日' # 毎月/毎年(営業日)
      t.integer :week,         comment: '週'    # 毎月/毎年(週)

      t.integer :wday,             comment: '曜日'      # 毎週, 毎月/毎年(週)
      t.integer :handling_holiday, comment: '休日の扱い' # 毎週, 毎月/毎年(日/週)

      t.integer :period, null: false, default: 1, comment: '期間（日）'

      t.datetime :deleted_at, comment: '削除日時'
      t.timestamps
    end
    add_index :task_cycles, [:space_id, :cycle, :month], name: 'index_task_cycles1'
    add_index :task_cycles, [:updated_at, :id],          name: 'index_task_cycles2'
  end
end
