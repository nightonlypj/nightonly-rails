require 'rails_helper'

RSpec.describe 'Tasks', type: :request do
  let(:response_json) { response.parsed_body }
  let(:response_json_task)  { response_json['task'] }
  let(:response_json_tasks) { response_json['tasks'] }
  let(:default_params) { { text: nil, priority: Task.priorities.keys.join(','), before: 1, active: 1, after: 0, sort: 'started_date', desc: 1 } }
  let_it_be(:created_user) { FactoryBot.create(:user) }

  # テスト内容（共通）
  shared_examples_for 'ToOK[ID]' do
    let!(:default_tasks_limit) { Settings.default_tasks_limit }
    before { Settings.default_tasks_limit = [default_tasks_limit, tasks.count].max }
    after  { Settings.default_tasks_limit = default_tasks_limit }
    it 'HTTPステータスが200。対象の名称が一致する' do
      is_expected.to eq(200)

      expect(response_json_tasks.count).to eq(tasks.count)
      tasks.each_with_index do |task, index|
        expect(response_json_tasks[tasks.count - index - 1]['id']).to eq(task.id)
      end

      string_keys = %i[text priority sort]
      input_params = params.to_h { |key, value| [key, string_keys.include?(key) ? value : value.to_i] }
      expect(response_json['search_params']).to eq(default_params.merge(input_params).stringify_keys)
    end
  end
  shared_examples_for 'ToOK[count](json)' do
    it 'HTTPステータスが200。件数が一致する' do
      is_expected.to eq(200)
      expect(response_json_tasks.count).to eq(tasks.count)

      string_keys = %i[text priority sort]
      input_params = params.to_h { |key, value| [key, string_keys.include?(key) ? value : value.to_i] }
      expect(response_json['search_params']).to eq(default_params.merge(input_params).stringify_keys)
    end
  end

  # GET /tasks/:space_code(.json) タスク一覧API
  # テストパターン
  #   未ログイン, APIログイン中, APIログイン中（削除予約済み）
  #   スペース: 存在しない, 公開, 非公開
  #   権限: ある（管理者〜閲覧者）, ない
  #   タスク: ない, 最大表示数と同じ, 最大表示数より多い
  #     優先度: 高, 中, 低, 未設定
  #     作成者: いる, アカウント削除済み
  #     最終更新者: いない, いる, アカウント削除済み
  #   ＋URLの拡張子: ない, .json
  #   ＋Acceptヘッダ: HTMLが含まれる, JSONが含まれる
  describe 'GET #index' do
    subject { get tasks_path(space_code: space.code, page: subject_page, format: subject_format), headers: auth_headers.merge(accept_headers) }

    let_it_be(:other_space) { FactoryBot.create(:space, created_user:) }

    # テスト内容
    shared_examples_for 'ToOK(json/json)' do
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      it 'HTTPステータスが200。対象項目が一致する' do
        is_expected.to eq(200)
        expect(response_json['success']).to be(true)
        expect(response_json['search_params']).to eq(default_params.stringify_keys)

        expect(response_json_task['total_count']).to eq(tasks.count)
        expect(response_json_task['current_page']).to eq(subject_page)
        expect(response_json_task['total_pages']).to eq((tasks.count - 1).div(Settings.default_tasks_limit) + 1)
        expect(response_json_task['limit_value']).to eq(Settings.default_tasks_limit)
        expect(response_json_task.count).to eq(4)

        expect(response_json.count).to eq(4)
      end
    end

    shared_examples_for 'リスト表示(json)' do |page|
      let(:subject_format) { :json }
      let(:accept_headers) { ACCEPT_INC_JSON }
      let(:subject_page) { page }
      let(:start_no)     { (Settings.default_tasks_limit * (page - 1)) + 1 }
      let(:end_no)       { [tasks.count, Settings.default_tasks_limit * page].min }
      it '件数・対象項目が一致する' do
        subject
        expect(response_json_tasks.count).to eq(end_no - start_no + 1)
        (start_no..end_no).each do |no|
          data = response_json_tasks[no - start_no]
          task = tasks[tasks.count - no]
          count = expect_task_json(data, task, task_cycles[task.id], nil, { detail: false, email: member&.power_admin? })
          expect(data.count).to eq(count)
        end
      end
    end

    # テストケース
    shared_examples_for 'タスク' do
      context 'ない' do
        include_context 'タスク一覧作成', 0, 0, 0, 0
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)', 1
        it_behaves_like 'リスト表示(json)', 1
      end
      context '最大表示数と同じ' do
        count = Settings.test_tasks_count
        include_context 'タスク一覧作成', count.high, count.middle, count.low, count.none
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)', 1
        it_behaves_like 'リスト表示(json)', 1
      end
      context '最大表示数より多い' do
        count = Settings.test_tasks_count
        include_context 'タスク一覧作成', count.high, count.middle, count.low, count.none + 1
        it_behaves_like 'ToNG(html)', 406
        it_behaves_like 'ToOK(json)', 1
        it_behaves_like 'ToOK(json)', 2
        it_behaves_like 'リスト表示(json)', 1
        it_behaves_like 'リスト表示(json)', 2
      end
    end

    shared_examples_for '[APIログイン中/削除予約済み][非公開]権限がある' do |power|
      let_it_be(:member) { FactoryBot.create(:member, power, space:, user:) }
      it_behaves_like 'タスク'
    end
    shared_examples_for '[APIログイン中/削除予約済み][非公開]権限がない' do
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 403
    end

    shared_examples_for '[*]スペースが存在しない' do
      let_it_be(:space) { FactoryBot.build_stubbed(:space) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 404
    end
    shared_examples_for '[*]スペースが公開' do
      let_it_be(:space) { FactoryBot.create(:space, :public, created_user:) }
      let(:member) { nil }
      it_behaves_like 'タスク'
    end
    shared_examples_for '[未ログイン]スペースが非公開' do
      let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
      it_behaves_like 'ToNG(html)', 406
      it_behaves_like 'ToNG(json)', 401
    end
    shared_examples_for '[APIログイン中/削除予約済み]スペースが非公開' do
      let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
      it_behaves_like '[APIログイン中/削除予約済み][非公開]権限がある', :admin
      it_behaves_like '[APIログイン中/削除予約済み][非公開]権限がある', :reader
      it_behaves_like '[APIログイン中/削除予約済み][非公開]権限がない'
    end

    shared_examples_for '[APIログイン中/削除予約済み]' do
      it_behaves_like '[*]スペースが存在しない'
      it_behaves_like '[*]スペースが公開'
      it_behaves_like '[APIログイン中/削除予約済み]スペースが非公開'
    end

    context '未ログイン' do
      include_context '未ログイン処理'
      it_behaves_like '[*]スペースが存在しない'
      it_behaves_like '[*]スペースが公開'
      it_behaves_like '[未ログイン]スペースが非公開'
    end
    context 'APIログイン中' do
      include_context 'APIログイン処理'
      it_behaves_like '[APIログイン中/削除予約済み]'
    end
    context 'APIログイン中（削除予約済み）' do
      include_context 'APIログイン処理', :destroy_reserved
      it_behaves_like '[APIログイン中/削除予約済み]'
    end
  end

  # 前提条件
  #   APIログイン中（URLの拡張子が.json/AcceptヘッダにJSONが含まれる）
  #   スペース非公開, 権限あり（管理者）, 検索オプションなし, IDのみ確認
  # テストパターン
  #   部分一致（大文字・小文字を区別しない）, 不一致: タイトル
  describe 'GET #index (.search)' do
    subject { get tasks_path(space_code: space.code, format: :json), params:, headers: auth_headers.merge(ACCEPT_INC_JSON) }

    include_context 'APIログイン処理'
    let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
    before_all { FactoryBot.create(:member, space:, user:) }
    let_it_be(:task) { FactoryBot.create(:task, space:, title: 'タイトル(Aaa)', created_user:) }

    # テストケース
    context '部分一致' do
      let(:params) { { text: 'aaa' } }
      let(:tasks) { [task] }
      it_behaves_like 'ToOK[ID]'
    end
    context '不一致' do
      let(:params) { { text: 'zzz' } }
      let(:tasks) { [] }
      it_behaves_like 'ToOK[ID]'
    end
  end

  # 前提条件
  #   APIログイン中（URLの拡張子が.json/AcceptヘッダにJSONが含まれる）
  #   スペース非公開, 権限あり, 検索テキスト、開始・終了日、並び順指定なし, IDのみ確認
  # テストパターン
  #   優先度: 高, 中, 低, 未設定 の組み合わせ
  describe 'GET #index (.by_priority)' do
    subject { get tasks_path(space_code: space.code, format: :json), params:, headers: auth_headers.merge(ACCEPT_INC_JSON) }

    include_context 'APIログイン処理'
    let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
    before_all { FactoryBot.create(:member, space:, user:) }
    let_it_be(:task_high)   { FactoryBot.create(:task, :high, space:, created_user:) }
    let_it_be(:task_middle) { FactoryBot.create(:task, :middle, space:, created_user:) }
    let_it_be(:task_low)    { FactoryBot.create(:task, :low, space:, created_user:) }
    let_it_be(:task_none)   { FactoryBot.create(:task, :none, space:, created_user:) }

    # テストケース
    context '■高, ■中, ■低, ■未設定' do
      let(:params) { { priority: 'high,middle,low,none' } }
      let(:tasks) { [task_high, task_middle, task_low, task_none] }
      it_behaves_like 'ToOK[ID]'
    end
    context '■高, ■中, ■低, □未設定' do
      let(:params) { { priority: 'high,middle,low' } }
      let(:tasks) { [task_high, task_middle, task_low] }
      it_behaves_like 'ToOK[ID]'
    end
    # NOTE: 多いので省略
    context '□高, ■中, ■低, ■未設定' do
      let(:params) { { priority: 'middle,low,none' } }
      let(:tasks) { [task_middle, task_low, task_none] }
      it_behaves_like 'ToOK[ID]'
    end
    context '■高, ■中, □低, □未設定' do
      let(:params) { { priority: 'high,middle' } }
      let(:tasks) { [task_high, task_middle] }
      it_behaves_like 'ToOK[ID]'
    end
    # NOTE: 多いので省略
    context '□高, □中, ■低, ■未設定' do
      let(:params) { { priority: 'low,none' } }
      let(:tasks) { [task_low, task_none] }
      it_behaves_like 'ToOK[ID]'
    end
    context '■高, □中, □低, □未設定' do
      let(:params) { { priority: 'high' } }
      let(:tasks) { [task_high] }
      it_behaves_like 'ToOK[ID]'
    end
    # NOTE: 多いので省略
    context '□高, □中, □低, ■未設定' do
      let(:params) { { priority: 'none' } }
      let(:tasks) { [task_none] }
      it_behaves_like 'ToOK[ID]'
    end
    context '□高, □中, □低, □未設定' do
      let(:params) { { priority: '' } }
      let(:tasks) { [] }
      it_behaves_like 'ToOK[ID]'
    end
  end

  # 前提条件
  #   APIログイン中（URLの拡張子が.json/AcceptヘッダにJSONが含まれる）
  #   スペース非公開, 権限あり, 検索テキスト、優先度、並び順指定なし, IDのみ確認
  # テストパターン
  #   開始・終了日: 開始前, 期間内, 終了後 の組み合わせ
  describe 'GET #index (.by_start_end_date)' do
    subject { get tasks_path(space_code: space.code, format: :json), params:, headers: auth_headers.merge(ACCEPT_INC_JSON) }

    include_context 'APIログイン処理'
    let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
    before_all { FactoryBot.create(:member, space:, user:) }
    let_it_be(:tasks_before) do
      [
        FactoryBot.create(:task, :before, :no_end, space:, created_user:),
        FactoryBot.create(:task, :before, space:, created_user:)
      ]
    end
    let_it_be(:tasks_active) do
      [
        FactoryBot.create(:task, :active, :no_end, space:, created_user:),
        FactoryBot.create(:task, :active, space:, created_user:)
      ]
    end
    let_it_be(:tasks_after) { [FactoryBot.create(:task, :after, space:, created_user:)] }

    # テストケース
    context '■開始前, ■期間内, ■終了後' do
      let(:params) { { before: '1', active: '1', after: '1' } }
      let(:tasks) { tasks_after + tasks_active + tasks_before }
      it_behaves_like 'ToOK[ID]'
    end
    context '■開始前, ■期間内, □終了後' do
      let(:params) { { before: '1', active: '1', after: '0' } }
      let(:tasks) { tasks_active + tasks_before }
      it_behaves_like 'ToOK[ID]'
    end
    context '■開始前, □期間内, ■終了後' do
      let(:params) { { before: '1', active: '0', after: '1' } }
      let(:tasks) { tasks_after + tasks_before }
      it_behaves_like 'ToOK[ID]'
    end
    context '□開始前, ■期間内, ■終了後' do
      let(:params) { { before: '0', active: '1', after: '1' } }
      let(:tasks) { tasks_after + tasks_active }
      it_behaves_like 'ToOK[ID]'
    end
    context '■開始前, □期間内, □終了後' do
      let(:params) { { before: '1', active: '0', after: '0' } }
      let(:tasks) { tasks_before }
      it_behaves_like 'ToOK[ID]'
    end
    context '□開始前, ■期間内, □終了後' do
      let(:params) { { before: '0', active: '1', after: '0' } }
      let(:tasks) { tasks_active }
      it_behaves_like 'ToOK[ID]'
    end
    context '□開始前, □期間内, ■終了後' do
      let(:params) { { before: '0', active: '0', after: '1' } }
      let(:tasks) { tasks_after }
      it_behaves_like 'ToOK[ID]'
    end
    context '□開始前, □期間内, □終了後' do
      let(:params) { { before: '0', active: '0', after: '0' } }
      let(:tasks) { [] }
      it_behaves_like 'ToOK[ID]'
    end
  end

  # 前提条件
  #   APIログイン中（URLの拡張子が.json/AcceptヘッダにJSONが含まれる）
  #   スペース非公開, 権限あり, 検索テキスト、優先度、開始・終了日指定なし, 件数のみ確認
  # テストパターン
  #   対象: 優先度, タイトル, 周期, 開始日, 終了日, 作成者, 作成日時, 最終更新者, 最終更新日時
  #   並び順: ASC, DESC  ※ASCは1つのみ確認
  describe 'GET #index (.order)' do
    subject { get tasks_path(space_code: space.code, format: :json), params:, headers: auth_headers.merge(ACCEPT_INC_JSON) }

    include_context 'APIログイン処理'
    let_it_be(:space) { FactoryBot.create(:space, :private, created_user:) }
    before_all { FactoryBot.create(:member, space:, user:) }
    let_it_be(:tasks) { FactoryBot.create_list(:task, 2, space:, created_user:) }

    # テストケース
    context '優先度 ASC' do
      let(:params) { { sort: 'priority', desc: '0' } }
      it_behaves_like 'ToOK[count](json)'
    end
    context '優先度 DESC' do
      let(:params) { { sort: 'priority', desc: '1' } }
      it_behaves_like 'ToOK[count](json)'
    end
    context 'タイトル DESC' do
      let(:params) { { sort: 'title', desc: '1' } }
      it_behaves_like 'ToOK[count](json)'
    end
    context '周期 DESC' do
      let(:params) { { sort: 'cycles', desc: '1' } }
      it_behaves_like 'ToOK[count](json)'
    end
    context '開始日 DESC' do
      let(:params) { { sort: 'started_date', desc: '1' } }
      it_behaves_like 'ToOK[count](json)'
    end
    context '終了日 DESC' do
      let(:params) { { sort: 'ended_date', desc: '1' } }
      it_behaves_like 'ToOK[count](json)'
    end
    context '作成者 DESC' do
      let(:params) { { sort: 'created_user.name', desc: '1' } }
      it_behaves_like 'ToOK[count](json)'
    end
    context '作成日時 DESC' do
      let(:params) { { sort: 'created_at', desc: '1' } }
      it_behaves_like 'ToOK[count](json)'
    end
    context '最終更新者 DESC' do
      let(:params) { { sort: 'last_updated_user.name', desc: '1' } }
      it_behaves_like 'ToOK[count](json)'
    end
    context '最終更新日時 DESC' do
      let(:params) { { sort: 'last_updated_at', desc: '1' } }
      it_behaves_like 'ToOK[count](json)'
    end
  end
end
