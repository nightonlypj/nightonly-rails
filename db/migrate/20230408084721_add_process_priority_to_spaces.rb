class AddProcessPriorityToSpaces < ActiveRecord::Migration[6.1]
  def change
    add_column :spaces, :process_priority, :integer, null: false, default: 3, comment: '処理優先度'

    add_index :spaces, [:process_priority, :id], name: 'index_spaces5'
  end
end
