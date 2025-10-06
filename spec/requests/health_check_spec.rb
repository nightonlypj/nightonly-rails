require 'rails_helper'

RSpec.describe 'HealthChecks', type: :request do
  # GET /health_check ヘルスチェック
  # テストパターン
  #   正常, DBエラー
  #   パラメータがない, 対象: 存在しない, db, all
  describe 'GET #index' do
    subject { get health_check_path, params: }

    # テスト内容
    shared_examples 'OK' do
      it 'HTTPステータスが200。OKが返却される' do
        is_expected.to eq(200)
        expect(response.body).to eq('OK')

        expect(ActiveRecord::Base.connection).not_to have_received(:execute)
      end
    end

    shared_examples 'OK(DB)' do
      it 'HTTPステータスが200。OKが返却される' do
        is_expected.to eq(200)
        expect(response.body).to eq('OK')

        expect(ActiveRecord::Base.connection).to have_received(:execute).once.with('SELECT 1')
      end
    end
    shared_examples 'NG(DB)' do
      it 'HTTPステータスが500。エラーメッセージが返却される' do
        is_expected.to eq(500)
        expect(response.body).to eq('ActiveRecord::DatabaseConnectionError')

        expect(ActiveRecord::Base.connection).to have_received(:execute).once.with('SELECT 1')
      end
    end

    # テストケース
    context '正常' do
      before { allow(ActiveRecord::Base.connection).to receive(:execute).with('SELECT 1').and_return(nil) }

      context 'パラメータがない' do
        let(:params) { nil }

        it_behaves_like 'OK'
      end
      context '対象が存在しない' do
        let(:params) { { target: 'not' } }

        it_behaves_like 'OK'
      end
      context '対象がdb' do
        let(:params) { { target: 'db' } }

        it_behaves_like 'OK(DB)'
      end
      context '対象がall' do
        let(:params) { { target: 'all' } }

        it_behaves_like 'OK(DB)'
      end
    end
    context 'DBエラー' do
      before { allow(ActiveRecord::Base.connection).to receive(:execute).with('SELECT 1').and_raise(ActiveRecord::DatabaseConnectionError) }

      context 'パラメータがない' do
        let(:params) { nil }

        it_behaves_like 'OK'
      end
      context '対象が存在しない' do
        let(:params) { { target: 'not' } }

        it_behaves_like 'OK'
      end
      context '対象がdb' do
        let(:params) { { target: 'db' } }

        it_behaves_like 'NG(DB)'
      end
      context '対象がall' do
        let(:params) { { target: 'all' } }

        it_behaves_like 'NG(DB)'
      end
    end
  end
end
