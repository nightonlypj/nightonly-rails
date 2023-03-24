require 'rails_helper'

RSpec.describe 'task_events/show', type: :view do
  before(:each) do
    @task_event = assign(:task_event, TaskEvent.create!(
                                        space: nil,
                                        task_cycle: nil
                                      ))
  end

  it 'renders attributes in <p>' do
    render
    expect(rendered).to match(//)
    expect(rendered).to match(//)
  end
end
