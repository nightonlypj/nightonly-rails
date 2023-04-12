Rails.application.routes.draw do
  get  'slack_users/:user_code',                         to: 'slack_users#index',  as: 'slack_users'
  post 'slack_users/:user_code/update/:slack_domain_id', to: 'slack_users#update', as: 'update_slack_user'
end
