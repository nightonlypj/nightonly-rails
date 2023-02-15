require 'rails_helper'

RSpec.describe 'tasks/index', type: :view do
  before(:each) do
    assign(:tasks, [
             Task.create!(
               space: nil
             ),
             Task.create!(
               space: nil
             )
           ])
  end

  it 'renders a list of tasks' do
    render
    assert_select 'tr>td', text: nil.to_s, count: 2
  end
end
