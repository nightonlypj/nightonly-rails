require 'rails_helper'

RSpec.describe 'slack_users/edit', type: :view do
  before(:each) do
    @slack_user = assign(:slack_user, SlackUser.create!(
                                        slack_domain: nil,
                                        user: nil,
                                        memberid: 'MyString',
                                        string: 'MyString'
                                      ))
  end

  it 'renders the edit slack_user form' do
    render

    assert_select 'form[action=?][method=?]', slack_user_path(@slack_user), 'post' do
      assert_select 'input[name=?]', 'slack_user[slack_domain_id]'

      assert_select 'input[name=?]', 'slack_user[user_id]'

      assert_select 'input[name=?]', 'slack_user[memberid]'

      assert_select 'input[name=?]', 'slack_user[string]'
    end
  end
end
