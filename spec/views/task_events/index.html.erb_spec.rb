require 'rails_helper'

RSpec.describe 'task_events/index', type: :view do
  before(:each) do
    assign(:task_events, [
             TaskEvent.create!(
               space: nil,
               task_cycle: nil
             ),
             TaskEvent.create!(
               space: nil,
               task_cycle: nil
             )
           ])
  end

  it 'renders a list of task_events' do
    render
    assert_select 'tr>td', text: nil.to_s, count: 2
    assert_select 'tr>td', text: nil.to_s, count: 2
  end
end
