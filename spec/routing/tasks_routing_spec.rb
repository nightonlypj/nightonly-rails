require 'rails_helper'

RSpec.describe TasksController, type: :routing do
  describe 'routing' do
    let(:space_code) { 'code0001' }

    it 'routes to #index' do
      expect(get: '/tasks').not_to be_routable
      expect(get: "/tasks/#{space_code}").to route_to('tasks#index', space_code: space_code)
      expect(get: "/tasks/#{space_code}.json").to route_to('tasks#index', space_code: space_code, format: 'json')
    end

    it 'routes to #show' do
      # expect(get: '/tasks/1').to route_to('tasks#show', id: '1') # NOTE: tasks#index
      expect(get: "/tasks/#{space_code}/detail/1").to route_to('tasks#show', space_code: space_code, id: '1')
      expect(get: "/tasks/#{space_code}/detail/1.json").to route_to('tasks#show', space_code: space_code, id: '1', format: 'json')
    end

    it 'routes to #new' do
      # expect(get: '/tasks/new').not_to be_routable # NOTE: tasks#index
      expect(get: "/tasks/#{space_code}/create").not_to be_routable
    end

    it 'routes to #create' do
      expect(post: '/tasks').not_to be_routable
      expect(post: "/tasks/#{space_code}/create").to route_to('tasks#create', space_code: space_code)
      expect(post: "/tasks/#{space_code}/create.json").to route_to('tasks#create', space_code: space_code, format: 'json')
    end

    it 'routes to #edit' do
      expect(get: '/tasks/1/edit').not_to be_routable
      expect(get: "/tasks/#{space_code}/update").not_to be_routable
      expect(get: "/tasks/#{space_code}/update/1").not_to be_routable
    end

    it 'routes to #update' do
      expect(put: '/tasks/1').not_to be_routable
      expect(patch: '/tasks/1').not_to be_routable
      expect(post: "/tasks/#{space_code}/update").not_to be_routable
      expect(post: "/tasks/#{space_code}/update/1").to route_to('tasks#update', space_code: space_code, id: '1')
      expect(post: "/tasks/#{space_code}/update/1.json").to route_to('tasks#update', space_code: space_code, id: '1', format: 'json')
    end

    it 'routes to #destroy' do
      expect(delete: '/tasks/1').not_to be_routable
      expect(post: "/tasks/#{space_code}/delete/1").to route_to('tasks#destroy', space_code: space_code, id: '1')
      expect(post: "/tasks/#{space_code}/delete/1.json").to route_to('tasks#destroy', space_code: space_code, id: '1', format: 'json')
    end
  end
end
