Rails.application.routes.draw do
  get  'task_events/:space_code',              to: 'task_events#index',   as: 'task_events'
  get  'task_events/:space_code/detail/:code', to: 'task_events#show',    as: 'task_event'
  post 'task_events/:space_code/update/:code', to: 'task_events#update',  as: 'update_task_event'
end
