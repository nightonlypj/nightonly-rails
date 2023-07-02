shared_context 'タスク一覧作成' do |high_count, middle_count, low_count, none_count|
  let_it_be(:tasks) do
    now = Time.current
    created_user = FactoryBot.create(:user)
    last_updated_user = FactoryBot.create(:user)
    destroy_user = FactoryBot.build_stubbed(:user)
    FactoryBot.create(:task, space: other_space, created_user:) # NOTE: 対象外

    FactoryBot.create_list(:task, high_count, :high, space:, created_user_id: destroy_user.id,
                                                     last_updated_user:, created_at: now - 4.days, updated_at: now - 5.days) +
      FactoryBot.create_list(:task, middle_count, :middle, space:, created_user:,
                                                           last_updated_user_id: destroy_user.id, created_at: now - 3.days, updated_at: now - 2.days) +
      FactoryBot.create_list(:task, low_count, :low, space:, created_user:,
                                                     last_updated_user: nil, created_at: now - 1.day, updated_at: now - 1.day) +
      FactoryBot.create_list(:task, none_count, :none, space:, created_user:,
                                                       last_updated_user: nil, created_at: now, updated_at: now)
  end

  let_it_be(:task_cycles) do
    FactoryBot.create(:task_cycle, :weekly, wday: :mon, task: tasks[0], deleted_at: Time.current) # NOTE: 対象外

    result = {}
    result[tasks[0].id] = [FactoryBot.create(:task_cycle, :weekly, task: tasks[0], wday: :wed, order: 1)] if tasks.count > 0
    result[tasks[1].id] = [FactoryBot.create(:task_cycle, :monthly, :day, task: tasks[1], order: 1)] if tasks.count > 1
    result[tasks[2].id] = [FactoryBot.create(:task_cycle, :yearly, :business_day, task: tasks[2], order: 1)] if tasks.count > 2
    result[tasks[3].id] = [FactoryBot.create(:task_cycle, :yearly, :week, task: tasks[3], order: 1)] if tasks.count > 3
    if tasks.count > 4
      task_cycle = FactoryBot.create(:task_cycle, :weekly, task: tasks[4], wday: :fri, handling_holiday: :after, order: 2)
      result[tasks[4].id] = [
        FactoryBot.create(:task_cycle, :weekly, task: tasks[4], wday: :mon, handling_holiday: :before, order: 1),
        task_cycle # NOTE: 並び順のテストの為、先にcreateする
      ]
    end

    result
  end
end

# テスト内容（共通）
def expect_task_json(response_json_task, task, task_cycles, use = { detail: false, cycles: false })
  result = 9
  expect(response_json_task['id']).to eq(task.id)
  expect(response_json_task['priority']).to eq(task.priority)
  expect(response_json_task['priority_i18n']).to eq(task.priority_i18n)
  expect(response_json_task['title']).to eq(task.title)
  if use[:detail]
    expect(response_json_task['summary']).to eq(task.summary)
    expect(response_json_task['premise']).to eq(task.premise)
    expect(response_json_task['process']).to eq(task.process)
    result += 3
  end
  expect(response_json_task['started_date']).to eq(I18n.l(task.started_date, format: :json))
  expect(response_json_task['ended_date']).to eq(I18n.l(task.ended_date, format: :json, default: nil))

  data = response_json_task['created_user']
  count = expect_user_json(data, task.created_user, { email: true })
  expect(data['deleted']).to eq(task.created_user.blank?)
  expect(data.count).to eq(count + 1)

  expect(response_json_task['created_at']).to eq(I18n.l(task.created_at, format: :json))

  data = response_json_task['last_updated_user']
  if task.last_updated_user_id.present?
    count = expect_user_json(data, task.last_updated_user, { email: true })
    expect(data['deleted']).to eq(task.last_updated_user.blank?)
    expect(data.count).to eq(count + 1)
    result += 1
  else
    expect(data).to be_nil
  end
  expect(response_json_task['last_updated_at']).to eq(I18n.l(task.last_updated_at, format: :json, default: nil))

  if use[:cycles]
    expect(response_json_task['cycles'].count).to eq(task_cycles.count)
    response_json_task['cycles'].each_with_index do |response_json_task_cycle, index|
      count = expect_task_cycle_json(response_json_task_cycle, task_cycles[index])
      expect(response_json_task_cycle.count).to eq(count)
    end
    result += 1
  end

  result
end

shared_context '[task]作成・更新条件' do
  let_it_be(:current_date) { Date.new(2022, 12, 10) }
  let(:valid_months) { %w[202209 202211 202212 202301] } # NOTE: 現在日と前後＋1ヶ月空けて前月、年を跨ぐように設定
  include_context '祝日設定(2022/11-2023/01)'
end

shared_examples_for '[task]パラメータなし' do |update|
  let_it_be(:task_cycles) { [FactoryBot.create(:task_cycle, task:, order: 1)] if update }
  let(:task_cycle_inactive) { nil }
  let(:params) { nil }
  it_behaves_like 'NG(html)'
  it_behaves_like 'ToNG(html)', 406
  it_behaves_like 'NG(json)'
  it_behaves_like 'ToNG(json)', 422, {
    cycles: [get_locale('errors.messages.task_cycles.blank')],
    priority: [get_locale('activerecord.errors.models.task.attributes.priority.blank')],
    started_date: [get_locale('activerecord.errors.models.task.attributes.started_date.blank')],
    title: [get_locale('activerecord.errors.models.task.attributes.title.blank')]
  }
end

shared_examples_for '[task]months/detailパラメータ' do
  context 'ない/ない' do
    let(:params) { { task: attributes } }
    let(:use_events) { false }
    it_behaves_like 'NG(html)'
    it_behaves_like 'ToNG(html)', 406
    it_behaves_like 'OK(json)'
    it_behaves_like 'ToOK(json)'
  end
  context 'ある/true' do
    let(:params) { { task: attributes, months: valid_months, detail: true } }
    let(:use_events) { true }
    it_behaves_like 'NG(html)'
    it_behaves_like 'ToNG(html)', 406
    it_behaves_like 'OK(json)'
    it_behaves_like 'ToOK(json)'
  end
  context '空/false' do
    let(:params) { { task: attributes, months: [], detail: false } }
    it_behaves_like 'NG(html)'
    it_behaves_like 'ToNG(html)', 406
    it_behaves_like 'NG(json)'
    it_behaves_like 'ToNG(json)', 422, { months: [get_locale('errors.messages.task.months.invalid', month: '')] }
  end
  context '不正値/ない' do
    let(:params) { { task: attributes, months: 'xxx' } }
    it_behaves_like 'NG(html)'
    it_behaves_like 'ToNG(html)', 406
    it_behaves_like 'NG(json)'
    it_behaves_like 'ToNG(json)', 422, { months: [get_locale('errors.messages.task.months.invalid', month: 'xxx')] }
  end
end

shared_examples_for '[task]有効なパラメータ' do |update|
  context "有効なパラメータ（毎週 × 削除なし/あり#{'、変更なし' if update}）" do
    let(:attributes) do
      valid_task_attributes.merge(
        cycles: [
          {
            cycle: :weekly,
            month: 1, # 保存されない
            target: :day, # 保存されない
            day: 1, # 保存されない
            business_day: 1, # 保存されない
            week: :first, # 保存されない
            wday: :mon,
            handling_holiday: :before,
            period: 1,
            delete: true
          },
          {
            cycle: :weekly,
            month: 2, # 保存されない
            target: :day, # 保存されない
            day: 2, # 保存されない
            business_day: 2, # 保存されない
            week: :second, # 保存されない
            wday: :tue,
            handling_holiday: :after,
            period: 2,
            delete: false
          }
        ]
      )
    end

    let(:task_cycle_inactive) { nil } # 元の値
    let(:except_task_cycle_inactive) { nil }
    let_it_be(:task_cycles) do # 元の値
      next unless update

      # NOTE: 2つ目が存在する + 1つ目はdelete -> 変更なし
      [FactoryBot.create(:task_cycle, :weekly, task:, wday: :tue, handling_holiday: :after, period: 2, order: 1)]
    end
    let(:expect_task_cycles_active) do
      [
        {
          cycle: :weekly,
          month: nil,
          target: nil,
          day: nil,
          business_day: nil,
          week: nil,
          wday: :tue,
          handling_holiday: :after,
          period: 2
        }
      ]
    end
    let(:expect_events) do # NOTE: 2022-12-10〜2023-01-31
      [
        { index: 0, started_date: '2022-12-12', last_ended_date: '2022-12-13' },
        { index: 0, started_date: '2022-12-19', last_ended_date: '2022-12-20' },
        { index: 0, started_date: '2022-12-26', last_ended_date: '2022-12-27' },
        { index: 0, started_date: '2022-12-30', last_ended_date: '2023-01-03' }, # NOTE: 祝日の為 <- started_date: '2023-01-02'
        { index: 0, started_date: '2023-01-06', last_ended_date: '2023-01-10' }, # NOTE: 祝日の為 <- started_date: '2023-01-09'
        { index: 0, started_date: '2023-01-16', last_ended_date: '2023-01-17' },
        { index: 0, started_date: '2023-01-23', last_ended_date: '2023-01-24' },
        { index: 0, started_date: '2023-01-30', last_ended_date: '2023-01-31' }
      ]
    end
    it_behaves_like '[task]months/detailパラメータ'
  end
  context "有効なパラメータ（毎月 × 日/営業日/週）#{'、追加あり' if update}" do
    let(:attributes) do
      valid_task_attributes.merge(
        cycles: [
          {
            cycle: :monthly,
            month: 1, # 保存されない
            target: :day,
            day: 1,
            business_day: 1, # 保存されない
            week: :first, # 保存されない
            wday: :mon, # 保存されない
            handling_holiday: :before,
            period: 1
          },
          {
            cycle: :monthly,
            month: 2, # 保存されない
            target: :business_day,
            day: 2, # 保存されない
            business_day: 2,
            week: :second, # 保存されない
            wday: :tue, # 保存されない
            handling_holiday: :before, # 保存されない
            period: 2
          },
          {
            cycle: :monthly,
            month: 3, # 保存されない
            target: :week,
            day: 3, # 保存されない
            business_day: 3, # 保存されない
            week: :third,
            wday: :wed,
            handling_holiday: :after,
            period: 3
          }
        ]
      )
    end

    let(:task_cycle_inactive) { nil } # 元の値
    let(:except_task_cycle_inactive) { nil }
    let_it_be(:task_cycles) do # 元の値
      next unless update

      # NOTE: 1つ目が存在する -> 2・3つ目を追加
      [FactoryBot.create(:task_cycle, :monthly, :day, task:, day: 1, handling_holiday: :before, period: 1, order: 1)]
    end
    let(:expect_task_cycles_active) do
      [
        {
          cycle: :monthly,
          month: nil,
          target: :day,
          day: 1,
          business_day: nil,
          week: nil,
          wday: nil,
          handling_holiday: :before,
          period: 1
        },
        {
          cycle: :monthly,
          month: nil,
          target: :business_day,
          day: nil,
          business_day: 2,
          week: nil,
          wday: nil,
          handling_holiday: nil,
          period: 2
        },
        {
          cycle: :monthly,
          month: nil,
          target: :week,
          day: nil,
          business_day: nil,
          week: :third,
          wday: :wed,
          handling_holiday: :after,
          period: 3
        }
      ]
    end
    let(:expect_events) do # NOTE: 2022-12-10〜2023-01-31
      [
        { index: 0, started_date: '2022-12-30', last_ended_date: '2022-12-30' },
        { index: 1, started_date: '2023-01-03', last_ended_date: '2023-01-04' }, # NOTE: 祝日の為 <- started_date: '2023-01-02, last_ended_date: '2023-01-03'
        { index: 2, started_date: '2022-12-19', last_ended_date: '2022-12-21' },
        { index: 2, started_date: '2023-01-16', last_ended_date: '2023-01-18' }
      ]
    end
    it_behaves_like '[task]months/detailパラメータ'
  end
  context "有効なパラメータ（毎年 × 日/営業日/週）#{'、削除・復帰・並び順変更あり' if update}" do
    let(:attributes) do
      valid_task_attributes.merge(
        cycles: [
          {
            cycle: :yearly,
            month: 1,
            target: :day,
            day: 1,
            business_day: 1, # 保存されない
            week: :first, # 保存されない
            wday: :mon, # 保存されない
            handling_holiday: :before,
            period: 1
          },
          {
            cycle: :yearly,
            month: 2,
            target: :business_day,
            day: 2, # 保存されない
            business_day: 2,
            week: :second, # 保存されない
            wday: :tue, # 保存されない
            handling_holiday: :before, # 保存されない
            period: 2
          },
          {
            cycle: :yearly,
            month: 3,
            target: :week,
            day: 3, # 保存されない
            business_day: 3, # 保存されない
            week: :third,
            wday: :wed,
            handling_holiday: :after,
            period: 3
          }
        ]
      )
    end

    let_it_be(:task_cycle_inactive) do # 元の値
      next unless update

      # NOTE: 3つ目が削除済みで存在する -> 復帰
      FactoryBot.create(:task_cycle, :yearly, :week, task:, month: 3, week: :third, wday: :wed, handling_holiday: :after, period: 3, order: 1, deleted_at: Time.current)
    end
    let_it_be(:except_task_cycle_inactive) { FactoryBot.create(:task_cycle, :weekly, task:, order: 2) if update }
    let_it_be(:task_cycles) do # 元の値
      next unless update

      [
        # NOTE: 2つ目が存在する + 3つ目が削除済みで存在する -> 1つ目を追加
        FactoryBot.create(:task_cycle, :yearly, :business_day, task:, month: 2, business_day: 2, period: 2, order: 1),
        except_task_cycle_inactive # NOTE: 存在しない -> 削除
      ]
    end
    let(:expect_task_cycles_active) do
      [
        {
          cycle: :yearly,
          month: 1,
          target: :day,
          day: 1,
          business_day: nil,
          week: nil,
          wday: nil,
          handling_holiday: :before,
          period: 1
        },
        {
          cycle: :yearly,
          month: 2,
          target: :business_day,
          day: nil,
          business_day: 2,
          week: nil,
          wday: nil,
          handling_holiday: nil,
          period: 2
        },
        {
          cycle: :yearly,
          month: 3,
          target: :week,
          day: nil,
          business_day: nil,
          week: :third,
          wday: :wed,
          handling_holiday: :after,
          period: 3
        }
      ]
    end
    let(:expect_events) do # NOTE: 2022-12-10〜2023-01-31
      [
        { index: 0, started_date: '2022-12-30', last_ended_date: '2022-12-30' }
      ]
    end
    it_behaves_like '[task]months/detailパラメータ'
  end
end

shared_examples_for '[task]無効なパラメータ' do |update|
  let_it_be(:task_cycles) { [FactoryBot.create(:task_cycle, task:, order: 1)] if update }
  let(:task_cycle_inactive) { nil }
  context '無効なパラメータ（タスクが不正値）' do
    let(:params) { { task: invalid_task_attributes.merge(cycles: [valid_cycle_attributes]) } }
    it_behaves_like 'NG(html)'
    it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
    it_behaves_like 'NG(json)'
    it_behaves_like 'ToNG(json)', 422, { title: [get_locale('activerecord.errors.models.task.attributes.title.blank')] }
  end
  context '無効なパラメータ（周期がない）' do
    let(:params) { { task: valid_task_attributes } }
    it_behaves_like 'NG(html)'
    it_behaves_like 'ToNG(html)', 406
    it_behaves_like 'NG(json)'
    it_behaves_like 'ToNG(json)', 422, { cycles: [get_locale('errors.messages.task_cycles.blank')] }
  end
  context '無効なパラメータ（周期が不正値）' do
    let(:params) { { task: valid_task_attributes.merge(cycles: [invalid_cycle_attributes]) } }
    it_behaves_like 'NG(html)'
    it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
    it_behaves_like 'NG(json)'
    it_behaves_like 'ToNG(json)', 422, { cycle1_cycle: [get_locale('activerecord.errors.models.task_cycle.attributes.cycle.blank')] }
  end
  context '無効なパラメータ（周期が文字）' do
    let(:params) { { task: valid_task_attributes.merge(cycles: 'x') } }
    it_behaves_like 'NG(html)'
    it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
    it_behaves_like 'NG(json)'
    it_behaves_like 'ToNG(json)', 422, { cycles: [get_locale('errors.messages.task_cycles.invalid')] }
  end
  context '無効なパラメータ（周期の曜日が重複）' do
    let(:weekly_cycle)  { FactoryBot.attributes_for(:task_cycle, :weekly) }
    let(:monthly_cycle) { FactoryBot.attributes_for(:task_cycle, :monthly, :week, wday: weekly_cycle[:wday]) }
    let(:params) { { task: valid_task_attributes.merge(cycles: [weekly_cycle, monthly_cycle]) } }
    it_behaves_like 'NG(html)'
    it_behaves_like 'ToNG(html)', 406
    it_behaves_like 'NG(json)'
    it_behaves_like 'ToNG(json)', 422, { cycle2_wday: [get_locale('activerecord.errors.models.task_cycle.attributes.wday.taken')] }
  end
  context '無効なパラメータ（周期の日が重複）' do
    let(:monthly_cycle) { FactoryBot.attributes_for(:task_cycle, :monthly, :day) }
    let(:yearly_cycle)  { FactoryBot.attributes_for(:task_cycle, :yearly, :day, day: monthly_cycle[:day]) }
    let(:params) { { task: valid_task_attributes.merge(cycles: [monthly_cycle, yearly_cycle]) } }
    it_behaves_like 'NG(html)'
    it_behaves_like 'ToNG(html)', 406
    it_behaves_like 'NG(json)'
    it_behaves_like 'ToNG(json)', 422, { cycle2_day: [get_locale('activerecord.errors.models.task_cycle.attributes.day.taken')] }
  end
  context '無効なパラメータ（周期の営業日が重複）' do
    let(:monthly_cycle) { FactoryBot.attributes_for(:task_cycle, :monthly, :business_day) }
    let(:yearly_cycle)  { FactoryBot.attributes_for(:task_cycle, :yearly, :business_day, business_day: monthly_cycle[:business_day]) }
    let(:params) { { task: valid_task_attributes.merge(cycles: [monthly_cycle, yearly_cycle]) } }
    it_behaves_like 'NG(html)'
    it_behaves_like 'ToNG(html)', 406
    it_behaves_like 'NG(json)'
    it_behaves_like 'ToNG(json)', 422, { cycle2_business_day: [get_locale('activerecord.errors.models.task_cycle.attributes.business_day.taken')] }
  end
  context '無効なパラメータ（周期が最大数より多い）' do
    let(:cycles) { (Settings.task_cycles_max_count + 1).times.map { |index| FactoryBot.attributes_for(:task_cycle, :monthly, :day, day: index + 1) } }
    let(:params) { { task: valid_task_attributes.merge(cycles:) } }
    it_behaves_like 'NG(html)'
    it_behaves_like 'ToNG(html)', 406 # NOTE: HTMLもログイン状態になる
    it_behaves_like 'NG(json)'
    it_behaves_like 'ToNG(json)', 422, { cycles: [get_locale('errors.messages.task_cycles.max_count', count: Settings.task_cycles_max_count)] }
  end
end
