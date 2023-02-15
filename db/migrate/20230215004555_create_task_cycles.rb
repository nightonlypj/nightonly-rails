class CreateTaskCycles < ActiveRecord::Migration[6.1]
  def change
    create_table :task_cycles do |t|
      t.references :task, null: false, foreign_key: true

      t.timestamps
    end
  end
end
