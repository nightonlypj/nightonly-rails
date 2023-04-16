require 'rails_helper'

RSpec.describe SlackUsersController, type: :routing do
  describe 'routing' do
    it 'routes to #index' do
      expect(get: '/slack_users').to route_to('slack_users#index')
      expect(get: '/slack_users.json').to route_to('slack_users#index', format: 'json')
    end

    it 'routes to #show' do
      expect(get: '/slack_users/1').not_to be_routable
    end

    it 'routes to #new' do
      expect(get: '/slack_users/new').not_to be_routable
    end

    it 'routes to #create' do
      expect(post: '/slack_users').not_to be_routable
    end

    it 'routes to #edit' do
      expect(get: '/slack_users/1/edit').not_to be_routable
    end

    it 'routes to #update' do
      expect(put: '/slack_users/1').not_to be_routable
      expect(patch: '/slack_users/1').not_to be_routable
      expect(post: '/slack_users/update').to route_to('slack_users#update')
      expect(post: '/slack_users/update.json').to route_to('slack_users#update', format: 'json')
    end

    it 'routes to #destroy' do
      expect(delete: '/slack_users/1').not_to be_routable
    end
  end
end
