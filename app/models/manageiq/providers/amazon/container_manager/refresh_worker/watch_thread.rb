class ManageIQ::Providers::Amazon::ContainerManager::RefreshWorker::WatchThread < ManageIQ::Providers::Kubernetes::ContainerManager::RefreshWorker::WatchThread
  private

  def noop?(notice)
    notice.object&.kind == "Endpoints" && filter_endpoint?(notice.object)
  end

  def filter_endpoint?(endpoint)
    # The base kubernetes parser uses the endpoint subset addresses and targetRefs
    # to build "container_groups_refs" in order to link pods to container_services
    #
    # If an endpoint doesn't have any subsets then it is a pointless update
    endpoint.subsets.blank?
  end
end
