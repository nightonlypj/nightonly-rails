require 'rails_helper'

RSpec.describe 'task_send_settings/show', type: :view do
  before(:each) do
    @task_send_setting = assign(:task_send_setting, TaskSendSetting.create!(
                                                      space: nil
                                                    ))
  end

  it 'renders attributes in <p>' do
    render
    expect(rendered).to match(//)
  end
end
