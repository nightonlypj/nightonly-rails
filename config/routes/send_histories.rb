Rails.application.routes.draw do
  get 'send_histories/:space_code',            to: 'send_histories#index', as: 'send_histories'
  get 'send_histories/:space_code/detail/:id', to: 'send_histories#show',  as: 'send_history'
end
