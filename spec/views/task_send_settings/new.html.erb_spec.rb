require 'rails_helper'

RSpec.describe 'task_send_settings/new', type: :view do
  before(:each) do
    assign(:task_send_setting, TaskSendSetting.new(
                                 space: nil
                               ))
  end

  it 'renders new task_send_setting form' do
    render

    assert_select 'form[action=?][method=?]', task_send_settings_path, 'post' do
      assert_select 'input[name=?]', 'task_send_setting[space_id]'
    end
  end
end
