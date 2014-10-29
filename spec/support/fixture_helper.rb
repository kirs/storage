module FixtureHelper
  def create_model_with_file(model, column, filename)
    if ENV['STORAGE_COLUMN_TYPE'] == "string"
      model.create!(column => filename)
    else
      model.create!(column => { filename: filename })
    end
  end
end
