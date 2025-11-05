module Storage
  module ServiceProfile
    module_function

    def disk_service?
      service = ActiveStorage::Blob.service
      service.is_a?(ActiveStorage::Service::DiskService)
    rescue StandardError
      false
    end

    def remote_service?
      !disk_service?
    end

    def service_name
      service = ActiveStorage::Blob.service
      if service.respond_to?(:name)
        service.name
      else
        service.class.name
      end
    rescue StandardError
      nil
    end
  end
end
