class TaskSendSetting < ApplicationRecord
  belongs_to :space
  belongs_to :created_user,      class_name: 'User', optional: true # NOTE: アカウント削除済みでも変更できるようにoptionalを追加
  belongs_to :last_updated_user, class_name: 'User', optional: true

  # 最終更新日時
  def last_updated_at
    updated_at == created_at ? nil : updated_at
  end
end
