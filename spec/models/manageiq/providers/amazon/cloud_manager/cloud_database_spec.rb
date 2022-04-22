describe ManageIQ::Providers::Amazon::CloudManager::CloudDatabase do
  let(:ems) do
    FactoryBot.create(:ems_amazon)
  end

  let(:cloud_database) do
    FactoryBot.create(:cloud_database_amazon, :ext_management_system => ems)
  end

  describe 'cloud database actions' do
    let(:connection) do
      double("Aws::RDS::Resource")
    end

    let(:rds_client) do
      double("Aws::RDS::Client")
    end

    before do
      allow(ems).to receive(:with_provider_connection).and_yield(connection)
      allow(connection).to receive(:client).and_return(rds_client)
    end

    context '#create_cloud_database' do
      it 'creates the cloud database' do
        expect(rds_client).to receive(:create_db_instance).with(:db_instance_identifier => "test-db",
                                                                :db_instance_class      => "db.t2.micro",
                                                                :allocated_storage      => 5,
                                                                :engine                 => "mysql",
                                                                :master_username        => "test123",
                                                                :master_user_password   => "test456")
        cloud_database.class.raw_create_cloud_database(ems, {:name     => "test-db",
                                                             :flavor   => "db.t2.micro",
                                                             :storage  => 5,
                                                             :database => "mysql",
                                                             :username => "test123",
                                                             :password => "test456"})
      end
    end
  end
end
