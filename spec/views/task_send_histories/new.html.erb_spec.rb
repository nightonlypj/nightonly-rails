require 'rails_helper'

RSpec.describe 'task_send_histories/new', type: :view do
  before(:each) do
    assign(:task_send_history, TaskSendHistory.new(
                                 space: nil,
                                 task_send_setting: nil
                               ))
  end

  it 'renders new task_send_history form' do
    render

    assert_select 'form[action=?][method=?]', task_send_histories_path, 'post' do
      assert_select 'input[name=?]', 'task_send_history[space_id]'

      assert_select 'input[name=?]', 'task_send_history[task_send_setting_id]'
    end
  end
end
