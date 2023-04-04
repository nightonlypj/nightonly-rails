class CreateTaskSendSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :task_send_settings do |t|
      t.references :space, null: false, foreign_key: true

      t.timestamps
    end
  end
end
