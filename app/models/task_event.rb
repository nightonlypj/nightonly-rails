class TaskEvent < ApplicationRecord
  belongs_to :space
  belongs_to :task_cycle
end
