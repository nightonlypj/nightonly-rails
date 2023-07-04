class AddInitAssignedToTaskEvents < ActiveRecord::Migration[6.1]
  def change
    add_reference :task_events, :init_assigned_user, type: :bigint, foreign_key: false, comment: '初期担当者ID'
  end
end
