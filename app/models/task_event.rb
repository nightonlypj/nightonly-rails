class TaskEvent < ApplicationRecord
  attr_accessor :assigned_user_code, :new_assigned_user

  belongs_to :space
  belongs_to :task_cycle
  belongs_to :init_assigned_user, class_name: 'User', optional: true # NOTE: アカウント削除済みでも変更できるようにoptionalを追加
  belongs_to :assigned_user, class_name: 'User', optional: true
  belongs_to :last_updated_user, class_name: 'User', optional: true

  validates :code, presence: true
  validates :code, uniqueness: { case_sensitive: true }, allow_blank: true
  validates :status, presence: true
  validates :memo, length: { maximum: Settings.task_event_memo_maximum }, allow_blank: true
  validates :last_ended_date, presence: true
  validate :validate_last_ended_date
  validate :validate_assigned_user_code

  scope :by_month, lambda { |months| # NOTE: monthsの形式が正しく、昇順の前提
    task_event = none
    index = 0
    while index < months.count
      start_month = "#{months[index]}01".to_date
      end_month = start_month

      while index + 1 < months.count
        next_start_month = "#{months[index + 1]}01".to_date
        break if next_start_month != end_month + 1.month

        end_month = next_start_month
        index += 1
      end

      task_event = task_event.or(where(started_date: start_month..end_month.end_of_month))
      index += 1
    end

    task_event
  }

  # ステータス
  NOT_NOTICE_STATUS = %i[complete unnecessary].freeze
  enum status: {
    untreated: 0,         # 未処理
    waiting_premise: 1,   # 前提対応待ち
    confirmed_premise: 2, # 前提確認済み
    processing: 4,        # 処理中
    pending: 5,           # 保留
    waiting_confirm: 7,   # 確認待ち
    complete: 8,          # 完了
    unnecessary: 9        # 対応不要
  }, _prefix: true

  # 最終更新日時
  def last_updated_at
    updated_at == created_at ? nil : updated_at
  end

  # Slackのステータス毎のアイコンを返却
  def slack_status_icon(type, notice_target)
    case type.to_sym
    when :next
      NOT_NOTICE_STATUS.include?(status.to_sym) ? ':sunny:' : ':alarm_clock:'
    when :expired
      NOT_NOTICE_STATUS.include?(status.to_sym) ? ':sunny:' : ':red_circle:'
    when :end_today
      case status.to_sym
      when :untreated, :waiting_premise, :confirmed_premise
        return ':warning:' if assigned_user.blank?

        notice_target.to_sym == :start ? ':cloud:' : ':umbrella:'
      when :processing, :pending
        ':cloud:'
      when :waiting_confirm, :complete, :unnecessary
        ':sunny:'
      else
        # :nocov:
        raise "type, status not found.(#{type}, #{status})"
        # :nocov:
      end
    when :date_include
      case status.to_sym
      when :untreated, :waiting_premise, :confirmed_premise
        assigned_user.blank? ? ':warning:' : ':cloud:'
      when :processing, :waiting_confirm, :complete, :unnecessary
        ':sunny:'
      when :pending
        ':cloud:'
      else
        # :nocov:
        raise "type, status not found.(#{type}, #{status})"
        # :nocov:
      end
    when :completed
      ':sunny:'
    else
      # :nocov:
      raise "type not found.(#{type})"
      # :nocov:
    end
  end

  private

  def validate_last_ended_date
    return if started_date.blank? || last_ended_date.blank?

    return errors.add(:last_ended_date, :after) if last_ended_date < started_date

    errors.add(:last_ended_date, :before) if last_ended_date > (started_date + 1.month).end_of_month
  end

  def validate_assigned_user_code
    return if assigned_user_code.blank?

    self.new_assigned_user = User.eager_load(:members).where(members: { space: [space, nil] }).find_by(code: assigned_user_code)
    key = TaskAssigne.check_assigned_user(new_assigned_user)
    errors.add(:assigned_user, key) if key.present?
  end
end
