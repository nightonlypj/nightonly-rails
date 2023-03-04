Rails.application.routes.draw do
  get  'tasks/:space_code',            to: 'tasks#index',   as: 'tasks'
  get  'tasks/:space_code/events',     to: 'tasks#events',  as: 'events_task'
  get  'tasks/:space_code/detail/:id', to: 'tasks#show',    as: 'task'
  post 'tasks/:space_code/create',     to: 'tasks#create',  as: 'create_task'
  post 'tasks/:space_code/update/:id', to: 'tasks#update',  as: 'update_task'
  post 'tasks/:space_code/delete/:id', to: 'tasks#destroy', as: 'destroy_task'
end
