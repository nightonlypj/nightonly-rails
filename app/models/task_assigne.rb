class TaskAssigne < ApplicationRecord
  belongs_to :space
  belongs_to :task

  # ユーザーIDsを設定
  def set_user_ids(assigned_users)
    if assigned_users.blank?
      self.user_ids = nil
      return {}
    end
    return { assigned_user1: I18n.t('errors.messages.assigned_users.invalid') } unless assigned_users.instance_of?(Array)

    errors = {}
    ids = []
    codes = assigned_users.pluck(:code)
    users = User.where(code: codes).eager_load(:members).where(members: { space: [space, nil] }).index_by(&:code)
    codes.each.with_index(1) do |code, index|
      key = self.class.check_assigned_user(users[code])
      if key.present?
        errors[:"assigned_user#{index}"] = I18n.t("errors.messages.assigned_users.code.#{key}")
        next
      end

      ids.push(users[code].id)
      break if ids.count > Settings.task_assigne_users_max_count
    end

    if ids.count > Settings.task_assigne_users_max_count
      errors[:assigned_user1] = I18n.t('errors.messages.assigned_users.max_count', count: Settings.task_assigne_users_max_count)
    end

    self.user_ids = ids.join(',') if errors.none?
    errors
  end

  # 担当者の状態を確認
  def self.check_assigned_user(user)
    return :notfound if user.blank?
    return :destroy_reserved if user.destroy_reserved?
    return :member_notfound if user.members.first.blank?
    return :member_power_reader if user.members.first.power_reader?

    nil
  end
end
