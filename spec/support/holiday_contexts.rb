shared_context '祝日設定(2022/11-2023/01)' do
  before_all do
    FactoryBot.create(:holiday, date: Date.new(2022, 11, 3), name: '文化の日')
    FactoryBot.create(:holiday, date: Date.new(2022, 11, 23), name: '勤労感謝の日')
    FactoryBot.create(:holiday, date: Date.new(2023, 1, 1), name: '元日')
    FactoryBot.create(:holiday, date: Date.new(2023, 1, 2), name: '休日')
    FactoryBot.create(:holiday, date: Date.new(2023, 1, 9), name: '成人の日')
  end
end
