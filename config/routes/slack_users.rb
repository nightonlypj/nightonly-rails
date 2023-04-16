Rails.application.routes.draw do
  get  'slack_users',        to: 'slack_users#index',  as: 'slack_users'
  post 'slack_users/update', to: 'slack_users#update', as: 'update_slack_user'
end
