Rails.application.routes.draw do
  get  'send_settings/:space_code/detail', to: 'send_settings#show',   as: 'send_setting'
  post 'send_settings/:space_code/update', to: 'send_settings#update', as: 'update_send_setting'
end
