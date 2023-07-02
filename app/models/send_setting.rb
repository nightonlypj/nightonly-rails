class SendSetting < ApplicationRecord
  belongs_to :space
  belongs_to :slack_domain, optional: true
  belongs_to :last_updated_user, class_name: 'User', optional: true # NOTE: アカウント削除済みでも変更できるようにoptionalを追加

  URL_FORMAT = %r{\Ahttps?://[A-Za-z0-9.-]+/[A-Za-z0-9.\-_/]+\Z}
  MENTION_FORMAT = /\A[A-Za-z0-9!^@|]*\Z/
  validates :slack_enabled, inclusion: { in: [true, false] } # NOTE: presenceだとfalseもエラーになる為
  validates :slack_webhook_url, presence: true, if: proc { |setting| setting.slack_enabled }
  validates :slack_webhook_url, length: { maximum: Settings.slack_webhook_url_maximum }, allow_blank: true
  validates :slack_webhook_url, format: { with: URL_FORMAT }, allow_blank: true, if: proc { errors[:slack_webhook_url].blank? }
  validates :slack_mention, length: { maximum: Settings.slack_mention_maximum }, allow_blank: true
  validates :slack_mention, format: { with: MENTION_FORMAT }, if: proc { errors[:slack_mention].blank? }
  validates :email_enabled, inclusion: { in: [true, false] } # NOTE: presenceだとfalseもエラーになる為
  validates :email_address, presence: true, if: proc { |setting| setting.email_enabled }
  validates :email_address, email: true, allow_blank: true
  validates :start_notice_start_hour, presence: true
  validates :start_notice_start_hour, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 22 }, allow_blank: true
  validates :start_notice_completed, inclusion: { in: [true, false] } # NOTE: presenceだとfalseもエラーになる為
  validates :start_notice_required, inclusion: { in: [true, false] } # NOTE: presenceだとfalseもエラーになる為
  validates :next_notice_start_hour, presence: true
  validates :next_notice_start_hour, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 23 }, allow_blank: true
  validates :next_notice_completed, inclusion: { in: [true, false] } # NOTE: presenceだとfalseもエラーになる為
  validates :next_notice_required, inclusion: { in: [true, false] } # NOTE: presenceだとfalseもエラーになる為
  validate :validate_start_hour

  scope :active, -> { where(deleted_at: nil) }
  scope :inactive, -> { where.not(deleted_at: nil) }

  private

  def validate_start_hour
    return if errors[:start_notice_start_hour].present? || errors[:next_notice_start_hour].present?

    errors.add(:next_notice_start_hour, :invalid) if next_notice_start_hour <= start_notice_start_hour
  end
end
