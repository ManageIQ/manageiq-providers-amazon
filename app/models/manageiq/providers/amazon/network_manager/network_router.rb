# frozen_string_literal: true

class ManageIQ::Providers::Amazon::NetworkManager::NetworkRouter < ::NetworkRouter

  BASE_QUEUE_OPTIONS = {
    :class_name => name,
    :priority   => MiqQueue::HIGH_PRIORITY,
    :role       => 'ems_operations',
  }.freeze

  # # ADD
  #
  # def self.raw_create_network_router(ext_management_system, options)
  #   cloud_tenant = options.delete(:cloud_tenant)
  #   name = options.delete(:name)
  #   router = nil
  #
  #   ext_management_system.with_provider_connection(connection_options(cloud_tenant)) do |service|
  #     router = service.create_router(name, options).body
  #   end
  #   {:ems_ref => router['id'], :name => options[:name]}
  # rescue => e
  #   _log.error "router=[#{options[:name]}], error: #{e}"
  #   raise MiqException::MiqNetworkRouterCreateError, parse_error_message_from_neutron_response(e), e.backtrace
  # end

  # EDIT

  def update_network_router_queue(userid, options = {})
    task_options = { :action => "updating Network Router for user #{userid}", :userid => userid }
    queue_options = base_queue_options.merge(:method_name => 'raw_update_network_router', :args => [options])
    MiqTask.generic_action_with_callback(task_options, queue_options)
  end

  def raw_update_network_router(options)
    with_connected_service { |service| service.update_router(ems_ref, options) }
  end

  # REMOVE

  def delete_network_router_queue(userid)
    task_options = { :action => "deleting Network Router for user #{userid}", :userid => userid }
    queue_options = base_queue_options.merge(:method_name => 'raw_delete_network_router', :args => [])
    MiqTask.generic_action_with_callback(task_options, queue_options)
  end

  def raw_delete_network_router
    with_connected_service { |service| service.delete_router(ems_ref) }
  end

  private

  def base_queue_options
    BASE_QUEUE_OPTIONS.merge(:instance_id => id, :zone => ext_management_system.my_zone)
  end

  def with_connected_service
    options = { :service => "Network" }
    options[:tenant_name] = cloud_tenant.name if cloud_tenant

    ext_management_system.with_provider_connection(options) do |service|
      yield service
    end

  rescue => e # TODO: handle specific error
    _log.error "router=[#{name}], error: #{e}"
    raise MiqException::MiqNetworkRouterDeleteError, parse_response_error(e), e.backtrace
  end

  def parse_response_error(e)
    e # stub
  end

end
