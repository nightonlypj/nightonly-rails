class TaskSendHistory < ApplicationRecord
  belongs_to :space
  belongs_to :task_send_setting
end
