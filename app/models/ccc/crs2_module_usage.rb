class Ccc::Crs2ModuleUsage < ActiveRecord::Base
  establish_connection :uscm

  self.table_name = 'crs2_module_usage'
  belongs_to :crs2_conference, class_name: 'Ccc::Crs2Conference', foreign_key: :conference_id
end
