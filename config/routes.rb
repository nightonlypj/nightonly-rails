Rails.application.routes.draw do
  draw :task_send_histories
  draw :task_send_settings
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
