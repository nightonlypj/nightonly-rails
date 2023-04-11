require 'rails_helper'

RSpec.describe 'slack_users/new', type: :view do
  before(:each) do
    assign(:slack_user, SlackUser.new(
                          slack_domain: nil,
                          user: nil,
                          memberid: 'MyString',
                          string: 'MyString'
                        ))
  end

  it 'renders new slack_user form' do
    render

    assert_select 'form[action=?][method=?]', slack_users_path, 'post' do
      assert_select 'input[name=?]', 'slack_user[slack_domain_id]'

      assert_select 'input[name=?]', 'slack_user[user_id]'

      assert_select 'input[name=?]', 'slack_user[memberid]'

      assert_select 'input[name=?]', 'slack_user[string]'
    end
  end
end
