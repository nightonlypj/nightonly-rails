require 'rake_helper'

RSpec.describe :task_event, type: :task do
  # 期間内のタスクイベント作成＋通知（作成・通知は開始時間以降）
  describe 'task_event:create_send_notice:now' do
    # TODO
  end

  # 期間内のタスクイベント作成＋通知（当日に実行できなかった場合に手動実行）
  #   TODO: 削除予約: ある, ない
  describe 'task_event:create_send_notice' do
    # TODO
  end
end
