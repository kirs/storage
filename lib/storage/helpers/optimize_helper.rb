module Storage::Helpers
  module OptimizeHelper
    def optimize_with_piet(image)
      check_piet_available

      Piet.optimize(image.path)
    end

    def check_piet_available
      begin
        require 'piet'
      rescue LoadError => e
        e.message << " (You may need to install the piet gem)"
        raise e
      end unless defined?(Piet)
    end
  end
end
