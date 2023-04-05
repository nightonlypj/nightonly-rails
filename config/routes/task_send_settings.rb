Rails.application.routes.draw do
  get  'task_send_settings/:space_code/detail', to: 'task_send_settings#show',   as: 'task_send_setting'
  post 'task_send_settings/:space_code/update', to: 'task_send_settings#update', as: 'update_task_send_setting'
end
