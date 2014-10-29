module Storage::Serializers
  class JsonSerializer
    def initialize(storage_model)
      @storage_model = storage_model
    end

    def dump
      {
        filename: @storage_model.filename,
        versions: versions
      }
    end

    private

    def versions
      versions_t = @storage_model.versions.map do |_, v|
        options = {
          key: v.remote_key,
          storage: v.storage_type
        }

        if v.meta_enabled?
          options[:meta] = v.meta
        end

        [v.name, options]
      end

      Hash[versions_t]
    end
  end
end
