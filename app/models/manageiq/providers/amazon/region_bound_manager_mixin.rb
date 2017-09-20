class ManageIQ::Providers::Amazon::RegionBoundManagerMixin

# TODO (Julian)

    private

    def create_discovered_region(region_name, access_key_id, secret_access_key, all_ems_names)
      name = region_name
      name = "#{region_name} #{access_key_id}" if all_ems_names.include?(name)
      while all_ems_names.include?(name)
        name_counter = name_counter.to_i + 1 if defined?(name_counter)
        name = "#{region_name} #{name_counter}"
      end

      new_ems = create!(
        :name            => name,
        :provider_region => region_name,
        :zone            => Zone.default_zone
      )
      new_ems.update_authentication(
        :default => {
          :userid   => access_key_id,
          :password => secret_access_key
        }
      )

      new_ems
    end
  end
end
