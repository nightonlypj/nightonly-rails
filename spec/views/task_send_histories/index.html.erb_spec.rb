require 'rails_helper'

RSpec.describe 'task_send_histories/index', type: :view do
  before(:each) do
    assign(:task_send_histories, [
             TaskSendHistory.create!(
               space: nil,
               task_send_setting: nil
             ),
             TaskSendHistory.create!(
               space: nil,
               task_send_setting: nil
             )
           ])
  end

  it 'renders a list of task_send_histories' do
    render
    assert_select 'tr>td', text: nil.to_s, count: 2
    assert_select 'tr>td', text: nil.to_s, count: 2
  end
end
