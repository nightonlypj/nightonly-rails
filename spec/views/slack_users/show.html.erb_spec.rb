require 'rails_helper'

RSpec.describe 'slack_users/show', type: :view do
  before(:each) do
    @slack_user = assign(:slack_user, SlackUser.create!(
                                        slack_domain: nil,
                                        user: nil,
                                        memberid: 'Memberid',
                                        string: 'String'
                                      ))
  end

  it 'renders attributes in <p>' do
    render
    expect(rendered).to match(//)
    expect(rendered).to match(//)
    expect(rendered).to match(/Memberid/)
    expect(rendered).to match(/String/)
  end
end
