class SlackDomain < ApplicationRecord
  has_many :slack_users, dependent: :destroy
end
