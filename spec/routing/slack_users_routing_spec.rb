require 'rails_helper'

RSpec.describe SlackUsersController, type: :routing do
  describe 'routing' do
    it 'routes to #index' do
      expect(get: '/slack_users').to route_to('slack_users#index')
    end

    it 'routes to #new' do
      expect(get: '/slack_users/new').to route_to('slack_users#new')
    end

    it 'routes to #show' do
      expect(get: '/slack_users/1').to route_to('slack_users#show', id: '1')
    end

    it 'routes to #edit' do
      expect(get: '/slack_users/1/edit').to route_to('slack_users#edit', id: '1')
    end

    it 'routes to #create' do
      expect(post: '/slack_users').to route_to('slack_users#create')
    end

    it 'routes to #update via PUT' do
      expect(put: '/slack_users/1').to route_to('slack_users#update', id: '1')
    end

    it 'routes to #update via PATCH' do
      expect(patch: '/slack_users/1').to route_to('slack_users#update', id: '1')
    end

    it 'routes to #destroy' do
      expect(delete: '/slack_users/1').to route_to('slack_users#destroy', id: '1')
    end
  end
end
