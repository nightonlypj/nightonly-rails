require 'rails_helper'

RSpec.describe 'task_send_settings/edit', type: :view do
  before(:each) do
    @task_send_setting = assign(:task_send_setting, TaskSendSetting.create!(
                                                      space: nil
                                                    ))
  end

  it 'renders the edit task_send_setting form' do
    render

    assert_select 'form[action=?][method=?]', task_send_setting_path(@task_send_setting), 'post' do
      assert_select 'input[name=?]', 'task_send_setting[space_id]'
    end
  end
end
