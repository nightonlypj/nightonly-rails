Rails.application.routes.draw do
  resources :tasks
  draw :downloads
  draw :members
  draw :invitations
  draw :spaces
  draw :infomations
  draw :admin
  draw :users
  root 'top#index'
  mount LetterOpenerWeb::Engine => '/letter_opener' if Rails.env.development?
end
