require 'rails_helper'

RSpec.describe 'slack_users/index', type: :view do
  before(:each) do
    assign(:slack_users, [
             SlackUser.create!(
               slack_domain: nil,
               user: nil,
               memberid: 'Memberid',
               string: 'String'
             ),
             SlackUser.create!(
               slack_domain: nil,
               user: nil,
               memberid: 'Memberid',
               string: 'String'
             )
           ])
  end

  it 'renders a list of slack_users' do
    render
    assert_select 'tr>td', text: nil.to_s, count: 2
    assert_select 'tr>td', text: nil.to_s, count: 2
    assert_select 'tr>td', text: 'Memberid'.to_s, count: 2
    assert_select 'tr>td', text: 'String'.to_s, count: 2
  end
end
