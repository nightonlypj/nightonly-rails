require 'rails_helper'

RSpec.describe TaskEventsController, type: :routing do
  describe 'routing' do
    it 'routes to #index' do
      expect(get: '/task_events').to route_to('task_events#index')
    end

    it 'routes to #new' do
      expect(get: '/task_events/new').to route_to('task_events#new')
    end

    it 'routes to #show' do
      expect(get: '/task_events/1').to route_to('task_events#show', id: '1')
    end

    it 'routes to #edit' do
      expect(get: '/task_events/1/edit').to route_to('task_events#edit', id: '1')
    end

    it 'routes to #create' do
      expect(post: '/task_events').to route_to('task_events#create')
    end

    it 'routes to #update via PUT' do
      expect(put: '/task_events/1').to route_to('task_events#update', id: '1')
    end

    it 'routes to #update via PATCH' do
      expect(patch: '/task_events/1').to route_to('task_events#update', id: '1')
    end

    it 'routes to #destroy' do
      expect(delete: '/task_events/1').to route_to('task_events#destroy', id: '1')
    end
  end
end
