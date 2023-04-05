require 'rails_helper'

RSpec.describe TaskSendHistoriesController, type: :routing do
  describe 'routing' do
    let(:space_code) { 'code0001' }

    it 'routes to #index' do
      expect(get: '/task_send_histories').not_to be_routable
      expect(get: "/task_send_histories/#{space_code}").to route_to('task_send_histories#index', space_code: space_code)
      expect(get: "/task_send_histories/#{space_code}.json").to route_to('task_send_histories#index', space_code: space_code, format: 'json')
    end

    it 'routes to #show' do
      # expect(get: '/task_send_histories/1').not_to be_routable # NOTE: task_send_histories#index
      expect(get: "/task_send_histories/#{space_code}/detail").to route_to('task_send_histories#show', space_code: space_code)
      expect(get: "/task_send_histories/#{space_code}/detail.json").to route_to('task_send_histories#show', space_code: space_code, format: 'json')
    end

    it 'routes to #new' do
      # expect(get: '/task_send_histories/new').not_to be_routable # NOTE: task_send_histories#index
    end

    it 'routes to #create' do
      expect(post: '/task_send_histories').not_to be_routable
    end

    it 'routes to #edit' do
      expect(get: '/task_send_histories/1/edit').not_to be_routable
    end

    it 'routes to #update' do
      expect(put: '/task_send_histories/1').not_to be_routable
      expect(patch: '/task_send_histories/1').not_to be_routable
    end

    it 'routes to #destroy' do
      expect(delete: '/task_send_histories/1').not_to be_routable
    end
  end
end
