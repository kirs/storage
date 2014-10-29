module Storage::Serializers
  class StringSerializer
    def initialize(storage_model)
      @storage_model = storage_model
    end

    def dump
      @storage_model.filename
    end
  end
end
