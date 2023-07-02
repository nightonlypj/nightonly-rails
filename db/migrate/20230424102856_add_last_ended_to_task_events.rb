class AddLastEndedToTaskEvents < ActiveRecord::Migration[6.1]
  def change
    add_column :task_events, :last_ended_date, :date, comment: '最終終了日'
    ActiveRecord::Base.connection.execute('UPDATE task_events SET last_ended_date = ended_date')
    change_column_null :task_events, :last_ended_date, false

    remove_index :task_events, [:space_id, :started_date, :ended_date, :id], name: 'index_task_events3'
    add_index    :task_events, [:space_id, :started_date, :id],              name: 'index_task_events3'
  end
end
