describe ManageIQ::Providers::Amazon::CloudManager::RefreshWorker do
  context "EMS with children" do
    let(:ems) { FactoryBot.create(:ems_amazon) }

    it ".queue_name_for_ems" do
      queue_name = described_class.queue_name_for_ems(ems)
      expect(queue_name.count).to eq(3)
      expect(queue_name.sort).to  eq(queue_name)
    end
  end

  context "EMS with no children" do
    let(:ems) { FactoryBot.create(:ems_storage) }

    it ".queue_name_for_ems" do
      queue_name = described_class.queue_name_for_ems(ems)
      expect(queue_name.count).to eq(1)
      expect(queue_name.first).to eq(ems.queue_name)
    end
  end
end
