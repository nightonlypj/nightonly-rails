class CreateTaskAssignes < ActiveRecord::Migration[6.1]
  def change
    create_table :task_assignes, comment: 'タスク担当者' do |t|
      t.references :space, null: false, type: :bigint, foreign_key: true, comment: 'スペースID'
      t.references :task,  null: false, type: :bigint, foreign_key: true, comment: 'タスクID'
      t.text :user_ids, comment: 'ユーザーIDs'

      t.timestamps
    end
    add_index :task_assignes, [:space_id, :task_id], unique: true, name: 'index_task_assignes1'
  end
end
