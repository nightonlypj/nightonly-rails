Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  #
  # Defines the root path route ("/")
  # root "articles#index"

  # :nocov:
  mount LetterOpenerWeb::Engine => '/letter_opener' if Rails.env.development?
  # :nocov:
  get '_health', to: 'health_check#index', as: 'health_check'
  scope '(:locale)', locale: /#{I18n.available_locales.map(&:to_s).join('|')}/ do
    root 'top#index'
  end

  draw :admin
  draw :downloads
  draw :holidays
  draw :infomations
  draw :invitations
  draw :members
  draw :send_histories
  draw :send_settings
  draw :slack_users
  draw :spaces
  draw :task_events
  draw :tasks
  draw :users
end
