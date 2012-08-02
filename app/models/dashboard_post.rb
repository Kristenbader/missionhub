class DashboardPost < ActiveRecord::Base
  self.table_name = 'mh_dashboard_posts'
  
  attr_accessible :context, :title, :video, :visible
  validates_presence_of :context, :title, :video
  
end