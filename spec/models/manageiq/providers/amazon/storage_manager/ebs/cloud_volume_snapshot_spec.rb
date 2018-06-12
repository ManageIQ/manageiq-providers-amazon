require_relative "../../aws_helper"

describe ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot do
  before { NotificationType.seed }
  let(:amazon) { FactoryGirl.create(:ems_amazon_with_authentication) }
  let(:ems) { FactoryGirl.create(:ems_amazon_ebs, :parent_ems_id => amazon.id) }
  let(:cloud_volume_snapshot) { FactoryGirl.create(:cloud_volume_snapshot_amazon, :ext_management_system => ems, :ems_ref => "snapshot_1") }

  describe "cloud volume operations" do
    context "#delete_snapshot" do
      it "deletes the cloud volume snapshot" do
        stubbed_responses = { :ec2 => { :delete_snapshot => {} } }
        allow(EmsRefresh).to receive(:queue_refresh)

        with_aws_stubbed(stubbed_responses) do
          expect { cloud_volume_snapshot.delete_snapshot }.to_not raise_error
          expect(cloud_volume_snapshot.status).to eq('deleting')
          expect(EmsRefresh).to have_received(:queue_refresh)
        end
      end

      it "catches error from the provider" do
        stubbed_responses = {
          :ec2 => {
            :delete_snapshot => "UnauthorizedOperation"
          }
        }

        with_aws_stubbed(stubbed_responses) do
          expect do
            cloud_volume_snapshot.delete_snapshot
          end.to raise_error(MiqException::MiqVolumeSnapshotDeleteError)
        end
      end
    end
  end
end
