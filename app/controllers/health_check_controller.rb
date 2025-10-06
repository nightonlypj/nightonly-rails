class HealthCheckController < ApplicationController
  # GET /health_check ヘルスチェック
  def index
    ActiveRecord::Base.connection.execute('SELECT 1') if %w[all db].include?(params[:target])

    render plain: 'OK'
  rescue ActiveRecord::ActiveRecordError => e
    render plain: e.class, status: :internal_server_error
  end
end
