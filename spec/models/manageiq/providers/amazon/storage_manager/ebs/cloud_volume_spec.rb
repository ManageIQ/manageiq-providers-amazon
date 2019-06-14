require_relative "../../aws_helper"

describe ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume do
  let(:ems_cloud) { FactoryBot.create(:ems_amazon_with_authentication) }
  let(:ebs) { FactoryBot.create(:ems_amazon_ebs, :parent_ems_id => ems_cloud.id) }
  let(:availability_zone) { FactoryBot.create(:availability_zone_amazon) }
  let(:cloud_volume) { FactoryBot.create(:cloud_volume_amazon_gp2, :ext_management_system => ebs, :ems_ref => "vol_1", :availability_zone => availability_zone) }

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
          expect(CloudVolume.create_volume(ebs.id, options)).to be_truthy
        end
      end
    end

    context "#update_volume" do
      let(:update_volume_name_stub) { { :create_tags => {}, :modify_volume => "failed" } }
      let(:modify_volume_stub) { { :create_tags => "failed", :modify_volume => {} } }
      let(:full_update_volume_stub) { { :create_tags => {}, :modify_volume => {} } }

      context "updating volume name" do
        it "is allowed when :name is provided" do
          with_aws_stubbed(:ec2 => update_volume_name_stub) do
            expect do
              cloud_volume.update_volume(:name => "new_name")
            end.not_to raise_error
          end
        end

        it "is allowed when all data are provided" do
          with_aws_stubbed(:ec2 => full_update_volume_stub) do
            expect do
              cloud_volume.update_volume(:name => "new_name", :size => 10, :volume_type => 'gp2')
            end.not_to raise_error
          end
        end

        it "is not allowed when :name is not provided" do
          with_aws_stubbed(:ec2 => modify_volume_stub) do
            expect do
              cloud_volume.update_volume(:size => 10, :volume_type => 'gp2')
            end.not_to raise_error
          end
        end
      end

      it "catches error from the provider" do
        stubbed_responses = {
          :ec2 => {
            :modify_volume => "UnauthorizedOperation"
          }
        }

        with_aws_stubbed(stubbed_responses) do
          expect do
            cloud_volume.update_volume(:volume_type => 'gp2', :size => 4)
          end.to raise_error(MiqException::MiqVolumeUpdateError)
        end
      end

      context "when modifying" do
        let(:volume) { FactoryBot.create(:cloud_volume_amazon_gp2, :ext_management_system => ebs, :ems_ref => "vol_1", :availability_zone => availability_zone) }
        let(:raw_client) { double }

        before do
          double.tap do |vol|
            allow(vol).to receive(:client).and_return(raw_client)
            allow(volume).to receive(:provider_object).and_return(vol)
          end
        end

        shared_examples_for "#modify_volume is allowed" do
          it "are properly set" do
            expect(raw_client).to receive(:modify_volume).with(modify_volume_options)

            with_aws_stubbed(:ec2 => modify_volume_stub) do
              volume.update_volume(options)
            end
          end
        end

        shared_examples_for "#modify_volume is not allowed" do
          it "is not allowed" do
            expect(raw_client).not_to receive(:modify_volume)
            with_aws_stubbed(:ec2 => modify_volume_stub) do
              volume.update_volume(options)
            end
          end
        end

        context "standard volume" do
          let(:options) { { :volume_type => "gp2", :iops => 200, :size => 4 } }
          let(:volume) { FactoryBot.create(:cloud_volume_amazon_standard, :ext_management_system => ebs, :ems_ref => "vol_1", :availability_zone => availability_zone) }

          include_examples "#modify_volume is not allowed"
        end

        context "volume configuration does not change" do
          let(:options) { { :volume_type => "gp2", :size => 1 } }

          include_examples "#modify_volume is not allowed"
        end

        context "volume type to gp2" do
          let(:options) { { :volume_type => "gp2", :iops => 200, :size => 4 } }
          # It must ignore IOPS param.
          let(:modify_volume_options) { { :volume_id => "vol_1", :size => 4 } }

          include_examples "#modify_volume is allowed"
        end

        context "volume type to io1" do
          let(:options) { { :volume_type => "io1", :iops => 200, :size => 4 } }
          # It must us all params.
          let(:modify_volume_options) { { :volume_id => "vol_1", :volume_type => "io1", :iops => 200, :size => 4 } }

          include_examples "#modify_volume is allowed"
        end

        context "only volume type" do
          let(:options) { { :volume_type => "io1" } }
          let(:modify_volume_options) { { :volume_id => "vol_1", :volume_type => "io1" } }

          include_examples "#modify_volume is allowed"
        end

        context "iops of a 'gp2' volume type" do
          let(:options) { { :iops => 200 } }

          include_examples "#modify_volume is not allowed"
        end

        context "iops of an 'io1' volume type" do
          let(:volume) { FactoryBot.create(:cloud_volume_amazon_io1, :ext_management_system => ebs, :ems_ref => "vol_1", :availability_zone => availability_zone) }
          let(:options) { { :iops => 200 } }
          let(:modify_volume_options) { { :volume_id => "vol_1", :iops => 200 } }

          include_examples "#modify_volume is allowed"
        end

        context "the size of the volume" do
          let(:options) { { :size => 4 } }
          let(:modify_volume_options) { { :volume_id => "vol_1", :size => 4 } }

          include_examples "#modify_volume is allowed"
        end

        context "the size of the volume with the same value" do
          let(:options) { { :size => 1 } }

          include_examples "#modify_volume is not allowed"
        end

        context "the size of the volume is valid string" do
          let(:options) { { :size => "4" } }
          let(:modify_volume_options) { { :volume_id => "vol_1", :size => 4 } }

          include_examples "#modify_volume is allowed"
        end

        context "the size of the volume is invalid string" do
          it "when invalid it should raise error" do
            with_aws_stubbed(:ec2 => modify_volume_stub) do
              expect do
                cloud_volume.update_volume(:size => "invalid")
              end.to raise_error(MiqException::MiqVolumeUpdateError)
            end
          end
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
      let(:instance) { FactoryBot.create(:vm_amazon, :ext_management_system => ems_cloud, :ems_ref => "instance_0") }

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
      let(:disk) { FactoryBot.create(:disk, :controller_type => "amazon", :device_type => "disk", :device_name => "sda1", :location => "sda1", :backing_id => cloud_volume.id) }
      let(:hardware) { FactoryBot.create(:hardware, :disks => [disk]) }
      let(:instance) { FactoryBot.create(:vm_amazon, :ext_management_system => ems_cloud, :ems_ref => "instance_0", :hardware => hardware) }

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

  describe "instance listing for attaching volumes" do
    let(:first_instance) { FactoryBot.create(:vm_amazon, :ext_management_system => ems_cloud, :ems_ref => "instance_0", :availability_zone => availability_zone) }
    let(:second_instance) { FactoryBot.create(:vm_amazon, :ext_management_system => ems_cloud, :ems_ref => "instance_1", :availability_zone => availability_zone) }
    let(:other_availability_zone) { FactoryBot.create(:availability_zone_amazon) }
    let(:other_instance) { FactoryBot.create(:vm_amazon, :ext_management_system => ems_cloud, :ems_ref => "instance_2", :availability_zone => other_availability_zone) }

    it "supports attachment to only those instances that are in the same availability zone" do
      expect(cloud_volume.availability_zone).to eq(availability_zone)
      expect(cloud_volume.available_vms).to contain_exactly(first_instance, second_instance)
    end
  end
end
