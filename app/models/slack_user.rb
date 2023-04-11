class SlackUser < ApplicationRecord
  belongs_to :slack_domain
  belongs_to :user
end
