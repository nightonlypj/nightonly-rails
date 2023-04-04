require 'rails_helper'

RSpec.describe 'task_send_histories/show', type: :view do
  before(:each) do
    @task_send_history = assign(:task_send_history, TaskSendHistory.create!(
                                                      space: nil,
                                                      task_send_setting: nil
                                                    ))
  end

  it 'renders attributes in <p>' do
    render
    expect(rendered).to match(//)
    expect(rendered).to match(//)
  end
end
