require 'rails_helper'

RSpec.describe 'task_send_settings/index', type: :view do
  before(:each) do
    assign(:task_send_settings, [
             TaskSendSetting.create!(
               space: nil
             ),
             TaskSendSetting.create!(
               space: nil
             )
           ])
  end

  it 'renders a list of task_send_settings' do
    render
    assert_select 'tr>td', text: nil.to_s, count: 2
  end
end
