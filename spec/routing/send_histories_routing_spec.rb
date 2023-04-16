require 'rails_helper'

RSpec.describe SendHistoriesController, type: :routing do
  describe 'routing' do
    let(:space_code) { 'code0001' }

    it 'routes to #index' do
      expect(get: '/send_histories').not_to be_routable
      expect(get: "/send_histories/#{space_code}").to route_to('send_histories#index', space_code: space_code)
      expect(get: "/send_histories/#{space_code}.json").to route_to('send_histories#index', space_code: space_code, format: 'json')
    end

    it 'routes to #show' do
      # expect(get: '/send_histories/1').not_to be_routable # NOTE: send_histories#index
      expect(get: "/send_histories/#{space_code}/detail/1").to route_to('send_histories#show', space_code: space_code, id: '1')
      expect(get: "/send_histories/#{space_code}/detail/1.json").to route_to('send_histories#show', space_code: space_code, id: '1', format: 'json')
    end

    it 'routes to #new' do
      # expect(get: '/send_histories/new').not_to be_routable # NOTE: send_histories#index
    end

    it 'routes to #create' do
      expect(post: '/send_histories').not_to be_routable
    end

    it 'routes to #edit' do
      expect(get: '/send_histories/1/edit').not_to be_routable
    end

    it 'routes to #update' do
      expect(put: '/send_histories/1').not_to be_routable
      expect(patch: '/send_histories/1').not_to be_routable
    end

    it 'routes to #destroy' do
      expect(delete: '/send_histories/1').not_to be_routable
    end
  end
end
