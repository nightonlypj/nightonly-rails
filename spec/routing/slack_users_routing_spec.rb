require 'rails_helper'

RSpec.describe SlackUsersController, type: :routing do
  describe 'routing' do
    let(:user_code)  { 'code000000000000000000001' }

    it 'routes to #index' do
      expect(get: '/slack_users').not_to be_routable
      expect(get: "/slack_users/#{user_code}").to route_to('slack_users#index', user_code: user_code)
      expect(get: "/slack_users/#{user_code}.json").to route_to('slack_users#index', user_code: user_code, format: 'json')
    end

    it 'routes to #show' do
      # expect(get: '/slack_users/1').not_to be_routable # NOTE: slack_users#index
    end

    it 'routes to #new' do
      # expect(get: '/slack_users/new').not_to be_routable # NOTE: slack_users#index
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
      expect(post: "/slack_users/#{user_code}/update").not_to be_routable
      expect(post: "/slack_users/#{user_code}/update/1").to route_to('slack_users#update', user_code: user_code, slack_domain_id: '1')
      expect(post: "/slack_users/#{user_code}/update/1.json").to route_to('slack_users#update', user_code: user_code, slack_domain_id: '1', format: 'json')
    end

    it 'routes to #destroy' do
      expect(delete: '/slack_users/1').not_to be_routable
    end
  end
end
