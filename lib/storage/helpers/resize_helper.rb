module Storage::Helpers
  module ResizeHelper
    def resize_to_fill(image, width, height, gravity = 'Center')
      cols, rows = image[:dimensions]
      image.combine_options do |cmd|
        if width != cols || height != rows
          scale_x = width / cols.to_f
          scale_y = height / rows.to_f
          if scale_x >= scale_y
            cols, rows = calc_cols_rows(scale_x, cols, rows)
            cmd.resize "#{cols}"
          else
            cols, rows = calc_cols_rows(scale_y, cols, rows)
            cmd.resize "x#{rows}"
          end
        end
        cmd.gravity gravity
        cmd.background "rgba(255,255,255,0.0)"
        cmd.extent "#{width}x#{height}" if cols != width || rows != height
      end
    end

    def resize_to_limit(image, width, height)
      image.resize "#{width}x#{height}>"
    end

    def resize_to_fit(image, width, height)
      image.resize "#{width}x#{height}"
    end
  end
end
