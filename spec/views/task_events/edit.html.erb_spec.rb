require 'rails_helper'

RSpec.describe 'task_events/edit', type: :view do
  before(:each) do
    @task_event = assign(:task_event, TaskEvent.create!(
                                        space: nil,
                                        task_cycle: nil
                                      ))
  end

  it 'renders the edit task_event form' do
    render

    assert_select 'form[action=?][method=?]', task_event_path(@task_event), 'post' do
      assert_select 'input[name=?]', 'task_event[space_id]'

      assert_select 'input[name=?]', 'task_event[task_cycle_id]'
    end
  end
end
