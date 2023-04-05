require 'rails_helper'

RSpec.describe TaskSendSettingsController, type: :routing do
  describe 'routing' do
    let(:space_code) { 'code0001' }

    it 'routes to #index' do
      expect(get: '/task_send_settings').not_to be_routable
    end

    it 'routes to #show' do
      expect(get: '/task_send_settings/1').not_to be_routable
      expect(get: "/task_send_settings/#{space_code}/detail").to route_to('task_send_settings#show', space_code: space_code)
      expect(get: "/task_send_settings/#{space_code}/detail.json").to route_to('task_send_settings#show', space_code: space_code, format: 'json')
    end

    it 'routes to #new' do
      expect(get: '/task_send_settings/new').not_to be_routable
    end

    it 'routes to #create' do
      expect(post: '/task_send_settings').not_to be_routable
    end

    it 'routes to #edit' do
      expect(get: '/task_send_settings/1/edit').not_to be_routable
    end

    it 'routes to #update' do
      expect(put: '/task_send_settings/1').not_to be_routable
      expect(patch: '/task_send_settings/1').not_to be_routable
      expect(post: "/task_send_settings/#{space_code}/update").to route_to('task_send_settings#update', space_code: space_code)
      expect(post: "/task_send_settings/#{space_code}/update.json").to route_to('task_send_settings#update', space_code: space_code, format: 'json')
    end

    it 'routes to #destroy' do
      expect(delete: '/task_send_settings/1').not_to be_routable
    end
  end
end
