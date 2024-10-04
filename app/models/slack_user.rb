class SlackUser < ApplicationRecord
  belongs_to :slack_domain
  belongs_to :user

  MEMBERID_FORMAT = /\A[A-Z0-9]*\Z/
  validates :memberid, length: { in: Settings.slack_user_memberid_minimum..Settings.slack_user_memberid_maximum }, allow_blank: true
  validates :memberid, format: { with: MEMBERID_FORMAT }, if: -> { errors[:memberid].blank? }
end
