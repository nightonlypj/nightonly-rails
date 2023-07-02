class CreateSlackUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :slack_users, comment: 'Slackユーザー' do |t|
      t.references :slack_domain, null: false, type: :bigint, foreign_key: true, comment: 'SlackドメインID'
      t.references :user,  null: false, type: :bigint, foreign_key: true, comment: 'ユーザーID'

      t.string :memberid, comment: 'SlackメンバーID'

      t.timestamps
    end
    add_index :slack_users, [:slack_domain_id, :user_id], unique: true, name: 'index_slack_users1'
    add_index :slack_users, [:user_id, :id],                            name: 'index_slack_users2'
  end
end
