require 'rails_helper'

RSpec.describe TaskAssigne, type: :model do
  let_it_be(:space) { FactoryBot.create(:space) }

  # ユーザーIDsを設定
  # テストパターン
  #  ない, 文字, [管理者]+[投稿者]+閲覧者+未参加+削除予定+削除済み, 最大数と同じ, 最大数より多い
  describe '#set_user_ids' do
    subject { task_assigne.set_user_ids(assigned_users) }
    let_it_be(:task_assigne) { FactoryBot.create(:task_assigne, space:) }
    include_context 'メンバーパターン作成(user)'
    include_context 'メンバーパターン作成(member)'
    let_it_be(:nojoin_user) { FactoryBot.create(:user) }

    # テスト内容
    before { task_assigne.user_ids = '0' }
    shared_examples_for 'user_ids' do
      it do # "user_idsに#{user_ids}がセットされる" do
        subject
        expect(task_assigne.user_ids).to eq(user_ids)
      end
    end

    # テストケース
    context 'ない' do
      let(:assigned_users) { nil }
      it_behaves_like 'Value', {}, '{}'
      let(:user_ids) { nil }
      it_behaves_like 'user_ids'
    end
    context '文字' do
      let(:assigned_users) { 'x' }
      it_behaves_like 'Value', { assigned_user1: get_locale('errors.messages.assigned_users.invalid') }
      let(:user_ids) { '0' } # 変更されない
      it_behaves_like 'user_ids'
    end
    context '[管理者]+[投稿者]+閲覧者+未参加+削除予定+削除済み' do
      let(:assigned_users) do
        [
          { code: user_admin.code },
          { code: user_writer.code },
          { code: user_reader.code },
          { code: nojoin_user.code },
          { code: user_destroy_reserved.code },
          { code: user_destroy.code }
        ]
      end
      it_behaves_like 'Value', {
        assigned_user3: get_locale('errors.messages.assigned_users.code.member_power_reader'),
        assigned_user4: get_locale('errors.messages.assigned_users.code.member_notfound'),
        assigned_user5: get_locale('errors.messages.assigned_users.code.destroy_reserved'),
        assigned_user6: get_locale('errors.messages.assigned_users.code.notfound')
      }
      let(:user_ids) { '0' } # 変更されない
      it_behaves_like 'user_ids'
    end
    context '最大数と同じ' do
      let(:assigned_users) { [{ code: user_admin.code }] + ([{ code: user_writer.code }] * (Settings.task_assigne_users_max_count - 1)) }
      it_behaves_like 'Value', {}, '{}'
      let(:user_ids) { ([user_admin.id] + ([user_writer.id] * (Settings.task_assigne_users_max_count - 1))).join(',') }
      it_behaves_like 'user_ids'
    end
    context '最大数より多い' do
      let(:assigned_users) { [{ code: user_admin.code }] + ([{ code: user_writer.code }] * Settings.task_assigne_users_max_count) }
      it_behaves_like 'Value', { assigned_user1: get_locale('errors.messages.assigned_users.max_count', count: Settings.task_assigne_users_max_count) }
      let(:user_ids) { '0' } # 変更されない
      it_behaves_like 'user_ids'
    end
  end

  # 担当者の状態を確認
  # テストパターン
  #   存在しない, 削除予約済み, 未参加, 閲覧者, 投稿者, 管理者
  describe '.check_assigned_user' do
    subject { described_class.check_assigned_user(user) }

    context '存在しない' do
      let(:user) { nil }
      it_behaves_like 'Value', :notfound
    end
    context '削除予約済み' do
      let(:user) { FactoryBot.create(:user, :destroy_reserved) }
      it_behaves_like 'Value', :destroy_reserved
    end
    context do
      let_it_be(:user) { FactoryBot.create(:user) }
      context '未参加' do
        it_behaves_like 'Value', :member_notfound
      end
      context '閲覧者' do
        before_all { FactoryBot.create(:member, :reader, space:, user:) }
        it_behaves_like 'Value', :member_power_reader
      end
      context '投稿者' do
        before_all { FactoryBot.create(:member, :writer, space:, user:) }
        it_behaves_like 'Value', nil, 'nil'
      end
      context '管理者' do
        before_all { FactoryBot.create(:member, :admin, space:, user:) }
        it_behaves_like 'Value', nil, 'nil'
      end
    end
  end
end
