describe ManageIQ::Providers::Amazon::CloudManager::RefreshWorker do
  context "EMS with children" do
    let!(:network_manager) { FactoryBot.create(:ems_network) }
    let!(:storage_manager) { FactoryBot.create(:ems_storage) }
    let(:ems) do
      FactoryBot.create(:ems_cloud).tap do |ems|
        network_manager.update_attributes(:parent_ems_id => ems.id)
        storage_manager.update_attributes(:parent_ems_id => ems.id)
      end
    end

    it ".queue_name_for_ems" do
      queue_name = described_class.queue_name_for_ems(ems)
      expect(queue_name.count).to eq(3)
      expect(queue_name.sort).to  eq(queue_name)
    end
  end

  context "EMS with no children" do
    let(:ems) { FactoryBot.create(:ems_cloud) }

    it ".queue_name_for_ems" do
      queue_name = described_class.queue_name_for_ems(ems)
      expect(queue_name.count).to eq(1)
      expect(queue_name.first).to eq(ems.queue_name)
    end
  end
end
