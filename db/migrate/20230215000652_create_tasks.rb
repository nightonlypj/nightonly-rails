class CreateTasks < ActiveRecord::Migration[6.1]
  def change
    create_table :tasks, comment: 'タスク' do |t|
      t.references :space, null: false, type: :bigint, foreign_key: true, comment: 'スペースID'

      t.integer :priority, null: false, default: 0, comment: '優先度'
      t.string  :title, null: false, comment: 'タイトル'
      t.text    :summary,            comment: '概要'
      t.text    :premise,            comment: '前提'
      t.text    :process,            comment: '手順'

      t.date :started_date, null: false, comment: '開始日'
      t.date :ended_date,                comment: '終了日'

      t.references :created_user, null: false, type: :bigint, foreign_key: false, comment: '作成者ID'
      t.references :last_updated_user,         type: :bigint, foreign_key: false, comment: '最終更新者ID'
      t.timestamps
    end
    add_index :tasks, [:space_id, :priority],                  name: 'index_tasks1'
    add_index :tasks, [:space_id, :started_date, :ended_date], name: 'index_tasks2'
    add_index :tasks, [:space_id, :ended_date],                name: 'index_tasks3'
    add_index :tasks, [:created_user_id, :id],                 name: 'index_tasks4'
    add_index :tasks, [:last_updated_user_id, :id],            name: 'index_tasks5'
    add_index :tasks, [:created_at, :id],                      name: 'index_tasks6'
    add_index :tasks, [:updated_at, :id],                      name: 'index_tasks7'
end
end
