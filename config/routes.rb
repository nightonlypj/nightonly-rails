Rails.application.routes.draw do
  draw :slack_users
  draw :send_histories
  draw :send_settings
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
  mount LetterOpenerWeb::Engine => '/letter_opener' if Rails.env.development?
end
