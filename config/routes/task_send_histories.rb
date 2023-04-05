Rails.application.routes.draw do
  get 'task_send_histories/:space_code',        to: 'task_send_histories#index', as: 'task_send_histories'
  get 'task_send_histories/:space_code/detail', to: 'task_send_histories#show',  as: 'task_send_history'
end
