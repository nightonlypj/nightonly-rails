Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  #
  # Defines the root path route ("/")
  # root "articles#index"

  draw :send_histories
  draw :send_settings
  draw :slack_users
  draw :task_events
  draw :tasks

  draw :downloads
  draw :members
  draw :invitations
  draw :spaces
  draw :holidays
  draw :infomations
  draw :admin
  draw :users
  root 'top#index'

  # :nocov:
  mount LetterOpenerWeb::Engine => '/letter_opener' if Rails.env.development?
  # :nocov:
end
