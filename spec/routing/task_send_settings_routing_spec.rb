require 'rails_helper'

RSpec.describe TaskSendSettingsController, type: :routing do
  describe 'routing' do
    it 'routes to #index' do
      expect(get: '/task_send_settings').to route_to('task_send_settings#index')
    end

    it 'routes to #new' do
      expect(get: '/task_send_settings/new').to route_to('task_send_settings#new')
    end

    it 'routes to #show' do
      expect(get: '/task_send_settings/1').to route_to('task_send_settings#show', id: '1')
    end

    it 'routes to #edit' do
      expect(get: '/task_send_settings/1/edit').to route_to('task_send_settings#edit', id: '1')
    end

    it 'routes to #create' do
      expect(post: '/task_send_settings').to route_to('task_send_settings#create')
    end

    it 'routes to #update via PUT' do
      expect(put: '/task_send_settings/1').to route_to('task_send_settings#update', id: '1')
    end

    it 'routes to #update via PATCH' do
      expect(patch: '/task_send_settings/1').to route_to('task_send_settings#update', id: '1')
    end

    it 'routes to #destroy' do
      expect(delete: '/task_send_settings/1').to route_to('task_send_settings#destroy', id: '1')
    end
  end
end
