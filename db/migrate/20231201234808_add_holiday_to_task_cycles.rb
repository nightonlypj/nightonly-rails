class AddHolidayToTaskCycles < ActiveRecord::Migration[7.0]
  def change
    add_column :task_cycles, :holiday, :boolean, null: false, default: false, comment: '休日含む'
  end
end
