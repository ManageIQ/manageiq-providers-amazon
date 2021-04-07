describe ManageIQ::Providers::Amazon::ContainerManager::Refresher do
  it ".ems_type" do
    expect(described_class.ems_type).to eq(:eks)
  end

  describe "#refresh" do
    let(:zone) do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      zone
    end

    let!(:ems) do
      hostname = Rails.application.secrets.amazon_eks[:hostname]
      cluster_name = Rails.application.secrets.amazon_eks[:cluster_name]

      FactoryBot.create(:ems_amazon_eks, :hostname => hostname, :port => 443, :uid_ems => cluster_name, :zone => zone).tap do |ems|
        client_id  = Rails.application.secrets.amazon_eks[:client_id]
        client_key = Rails.application.secrets.amazon_eks[:client_secret]

        ems.update_authentication(:default => {:userid => client_id, :password => client_key})
      end
    end

    it "will perform a full refresh" do
      2.times do
        VCR.use_cassette(described_class.name.underscore) { EmsRefresh.refresh(ems) }

        ems.reload

        assert_table_counts
        assert_specific_container_project
        assert_specific_container_group
        assert_specific_container
      end
    end

    def assert_table_counts
      expect(ems.container_projects.count).to eq(4)
      expect(ems.container_nodes.count).to eq(0)
      expect(ems.container_groups.count).to eq(2)
      expect(ems.containers.count).to eq(2)
    end

    def assert_specific_container_project
      container_project = ems.container_projects.find_by(:name => "kube-system")
      expect(container_project).to have_attributes(
        :name             => "kube-system",
        :resource_version => "4"
      )
    end

    def assert_specific_container_group
      container_group = ems.container_groups.find_by(:name => "coredns-c79dcb98c-v6chb")
      expect(container_group).to have_attributes(
        :ems_ref           => "8bca6c7d-b5a0-48f1-a8a7-984586bd80a6",
        :name              => "coredns-c79dcb98c-v6chb",
        :resource_version  => "1066525",
        :restart_policy    => "Always",
        :dns_policy        => "Default",
        :type              => "ManageIQ::Providers::Amazon::ContainerManager::ContainerGroup",
        :container_project => ems.container_projects.find_by(:name => "kube-system"),
        :phase             => "Pending"
      )
    end

    def assert_specific_container
      container = ems.containers.find_by(:name => "coredns", :container_group => ems.container_groups.find_by(:name => "coredns-c79dcb98c-v6chb"))
      expect(container).to have_attributes(
        :ems_ref              => "8bca6c7d-b5a0-48f1-a8a7-984586bd80a6_coredns_602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/coredns:v1.7.0-eksbuild.1",
        :name                 => "coredns",
        :type                 => "ManageIQ::Providers::Amazon::ContainerManager::Container",
        :request_cpu_cores    => 0.1,
        :request_memory_bytes => 73_400_320,
        :limit_cpu_cores      => nil,
        :limit_memory_bytes   => 178_257_920,
        :image                => "602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/coredns:v1.7.0-eksbuild.1",
        :image_pull_policy    => "IfNotPresent",
        :memory               => nil,
        :cpu_cores            => 0.0,
        :container_group      => ems.container_groups.find_by(:name => "coredns-c79dcb98c-v6chb"),
        :capabilities_add     => "NET_BIND_SERVICE",
        :capabilities_drop    => "all"
      )
    end
  end
end
