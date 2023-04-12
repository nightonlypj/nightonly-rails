class CreateSlackDomains < ActiveRecord::Migration[6.1]
  def change
    create_table :slack_domains, comment: 'Slackドメイン' do |t|
      t.string :name, null: false, comment: 'ドメイン名'

      t.timestamps
    end
    add_index :slack_domains, :name, unique: true, name: 'index_slack_domains1'
  end
end
