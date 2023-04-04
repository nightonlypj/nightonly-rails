class CreateTaskSendHistories < ActiveRecord::Migration[6.1]
  def change
    create_table :task_send_histories do |t|
      t.references :space, null: false, foreign_key: true
      t.references :task_send_setting, null: false, foreign_key: true

      t.timestamps
    end
  end
end
