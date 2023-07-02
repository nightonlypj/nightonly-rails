class SlackDomain < ApplicationRecord
  has_many :slack_users, dependent: :destroy

  NAME_FORMAT = /\A[a-z0-9-]*\Z/
  validates :name, presence: true
  validates :name, length: { maximum: Settings.slack_domain_name_maximum }, allow_blank: true
  validates :name, format: { with: NAME_FORMAT }, if: proc { errors[:name].blank? }
  validates :name, uniqueness: { case_sensitive: true }, allow_blank: true, if: proc { errors[:name].blank? }
end
