class AddOrderToTaskCycles < ActiveRecord::Migration[6.1]
  def change
    add_column :task_cycles, :order, :integer, comment: '並び順'

    add_index :task_cycles, [:order, :updated_at, :id], name: 'index_task_cycles4'
  end
end
