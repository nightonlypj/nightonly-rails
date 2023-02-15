require 'rails_helper'

RSpec.describe 'tasks/new', type: :view do
  before(:each) do
    assign(:task, Task.new(
                    space: nil
                  ))
  end

  it 'renders new task form' do
    render

    assert_select 'form[action=?][method=?]', tasks_path, 'post' do
      assert_select 'input[name=?]', 'task[space_id]'
    end
  end
end
