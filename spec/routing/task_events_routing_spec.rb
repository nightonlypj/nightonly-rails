require 'rails_helper'

RSpec.describe TaskEventsController, type: :routing do
  describe 'routing' do
    let(:space_code) { 'code0001' }

    it 'routes to #index' do
      expect(get: '/task_events').not_to be_routable
      expect(get: "/task_events/#{space_code}").to route_to('task_events#index', space_code: space_code)
      expect(get: "/task_events/#{space_code}.json").to route_to('task_events#index', space_code: space_code, format: 'json')
    end

    it 'routes to #show' do
      # expect(get: '/task_events/1').to route_to('task_events#show', id: '1') # NOTE: task_events#index
      expect(get: "/task_events/#{space_code}/detail/1").to route_to('task_events#show', space_code: space_code, id: '1')
      expect(get: "/task_events/#{space_code}/detail/1.json").to route_to('task_events#show', space_code: space_code, id: '1', format: 'json')
    end

    it 'routes to #new' do
      # expect(get: '/task_events/new').not_to be_routable # NOTE: task_events#index
      expect(get: "/task_events/#{space_code}/create").not_to be_routable
    end

    it 'routes to #create' do
      expect(post: '/task_events').not_to be_routable
    end

    it 'routes to #edit' do
      expect(get: '/task_events/1/edit').not_to be_routable
    end

    it 'routes to #update' do
      expect(put: '/task_events/1').not_to be_routable
      expect(patch: '/task_events/1').not_to be_routable
      expect(post: "/task_events/#{space_code}/update").not_to be_routable
      expect(post: "/task_events/#{space_code}/update/1").to route_to('task_events#update', space_code: space_code, id: '1')
      expect(post: "/task_events/#{space_code}/update/1.json").to route_to('task_events#update', space_code: space_code, id: '1', format: 'json')
    end

    it 'routes to #destroy' do
      expect(delete: '/task_events/1').not_to be_routable
    end
  end
end
