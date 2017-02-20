require_relative "../../aws_helper"

describe ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume do
  let(:ems_cloud) { FactoryGirl.create(:ems_amazon_with_authentication) }
  let(:ebs) { FactoryGirl.create(:ems_amazon_ebs, :parent_ems_id => ems_cloud.id) }
  let(:cloud_volume) { FactoryGirl.create(:cloud_volume_amazon, :ext_management_system => ebs, :ems_ref => "vol_1") }

  describe "cloud volume operations" do
    context ".raw_create_volume" do
      it "creates a volume" do
        stubbed_responses = {
          :ec2 => {
            :create_volume => {
              :volume_id         => "volume_id",
              :size              => 1,
              :availability_zone => "az1",
              :state             => "creating",
              :volume_type       => "gp2"
            },
            :create_tags   => {}
          }
        }

        options = {
          :name              => "volume",
          :availability_zone => "az1",
          :size              => 1,
          :volume_type       => "gp2",
        }

        with_aws_stubbed(stubbed_responses) do
          expect(CloudVolume.create_volume(ebs, options)).to be_truthy
        end
      end
    end

    context "#delete_volume" do
      it "deletes the cloud volume" do
        stubbed_responses = {
          :ec2 => {
            :delete_volume => {}
          }
        }

        with_aws_stubbed(stubbed_responses) do
          expect(cloud_volume.delete_volume).to be_truthy
        end
      end

      it "catches error from the provider" do
        stubbed_responses = {
          :ec2 => {
            :delete_volume => "UnauthorizedOperation"
          }
        }

        with_aws_stubbed(stubbed_responses) do
          expect do
            cloud_volume.delete_volume
          end.to raise_error(MiqException::MiqVolumeDeleteError)
        end
      end
    end

    context "#attach_volume" do
      let(:instance) { FactoryGirl.create(:vm_amazon, :ext_management_system => ems_cloud, :ems_ref => "instance_0") }

      it "attaches the cloud volume" do
        stubbed_responses = {
          :ec2 => {
            :attach_volume => {
              :volume_id   => cloud_volume.ems_ref,
              :instance_id => instance.ems_ref,
              :device      => "/dev/sdm"
            }
          }
        }

        with_aws_stubbed(stubbed_responses) do
          expect(cloud_volume.attach_volume(instance.ems_ref, "/dev/sdm")).to be_truthy
        end
      end
    end

    context "#detach_volume" do
      # Register the attachment of the volume to an instance.
      let(:disk) { FactoryGirl.create(:disk, :controller_type => "amazon", :device_type => "disk", :device_name => "sda1", :location => "sda1", :backing_id => cloud_volume.id) }
      let(:hardware) { FactoryGirl.create(:hardware, :disks => [disk]) }
      let(:instance) { FactoryGirl.create(:vm_amazon, :ext_management_system => ems_cloud, :ems_ref => "instance_0", :hardware => hardware) }

      it "detaches the cloud volume" do
        stubbed_responses = {
          :ec2 => {
            :detach_volume => {}
          }
        }

        with_aws_stubbed(stubbed_responses) do
          expect(cloud_volume.detach_volume(instance.ems_ref)).to be_truthy
        end
      end
    end
  end
end
