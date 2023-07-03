class CreateTaskAssignes < ActiveRecord::Migration[6.1]
  def change
    create_table :task_assignes do |t|
      t.references :space, null: false, foreign_key: true
      t.references :task, null: false, foreign_key: true

      t.timestamps
    end
  end
end
