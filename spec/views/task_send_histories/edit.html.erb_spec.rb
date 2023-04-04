require 'rails_helper'

RSpec.describe 'task_send_histories/edit', type: :view do
  before(:each) do
    @task_send_history = assign(:task_send_history, TaskSendHistory.create!(
                                                      space: nil,
                                                      task_send_setting: nil
                                                    ))
  end

  it 'renders the edit task_send_history form' do
    render

    assert_select 'form[action=?][method=?]', task_send_history_path(@task_send_history), 'post' do
      assert_select 'input[name=?]', 'task_send_history[space_id]'

      assert_select 'input[name=?]', 'task_send_history[task_send_setting_id]'
    end
  end
end
