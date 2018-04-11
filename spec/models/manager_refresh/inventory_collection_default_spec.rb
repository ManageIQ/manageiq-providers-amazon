# frozen_string_literal: true

describe ManagerRefresh::InventoryCollectionDefault do
  let(:ems) { new_amazon_ems }

  it 'pickups existing Vm and MiqTemplate records on Amazon EMS re-adding' do
    ems = new_amazon_ems

    with_vcr_data { expect { EmsRefresh.refresh(ems) }.to change { VmOrTemplate.count }.from(0) }
    expect { ems.destroy }.to_not change { VmOrTemplate.count }

    aggregate_failures do
      expect(Vm.count).to_not be_zero
      expect(MiqTemplate.count).to_not be_zero
      expect(ExtManagementSystem.count).to be_zero
    end

    ems = new_amazon_ems

    with_vcr_data do
      expect { EmsRefresh.refresh(ems) }
        .to  change { VmOrTemplate.distinct.pluck(:ems_id) }.from([nil]).to([ems.id])
        .and change { VmOrTemplate.count } .by(0)
        .and change { MiqTemplate.count }  .by(0)
        .and change { Vm.count }           .by(0)
    end
  end

  context 'label tag mapping' do
    before(:context) do
      tag = Tag.find_or_create_by!(:name => '/managed/amazon:vm:some_tag')
      Classification
        .create_with(:example_text => 'Example Tag Mapping Classification (text)',
                     :description  => 'Example tag mapping classification (description)')
        .find_or_create_by!(:tag => tag)
      ContainerLabelTagMapping
        .find_or_create_by!(:tag                   => tag,
                            :label_name            => 'some_tag',
                            :labeled_resource_type => 'Vm')
    end

    it 'pickups existing items on refresh' do
      with_vcr_data do
        expect { EmsRefresh.refresh(ems) }
          .to  change { CustomAttribute.count } .from(0)
          .and change { Classification.count }  .from(1)
          .and change { Tag.count }             .from(1)
          .and change { Tagging.count }         .from(0)

        expect { EmsRefresh.refresh(ems) }
          .to  change { CustomAttribute.count } .by(0)
          .and change { Classification.count }  .by(0)
          .and change { Tag.count }             .by(0)
          .and change { Tagging.count }         .by(0)
      end
    end
  end

  private

  def new_amazon_ems
    FactoryGirl.create(:ems_amazon_with_vcr_authentication, :provider_region => 'eu-central-1')
  end

  # TODO: (zalex) DRY - put in the shared helpers
  def with_vcr_data
    VCR.use_cassette(described_class.name.underscore, :allow_unused_http_interactions => true) { yield }
  end
end
