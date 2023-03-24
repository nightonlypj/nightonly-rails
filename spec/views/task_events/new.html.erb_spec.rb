require 'rails_helper'

RSpec.describe 'task_events/new', type: :view do
  before(:each) do
    assign(:task_event, TaskEvent.new(
                          space: nil,
                          task_cycle: nil
                        ))
  end

  it 'renders new task_event form' do
    render

    assert_select 'form[action=?][method=?]', task_events_path, 'post' do
      assert_select 'input[name=?]', 'task_event[space_id]'

      assert_select 'input[name=?]', 'task_event[task_cycle_id]'
    end
  end
end
