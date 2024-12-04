class ExtRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :ext, reading: :ext }
end