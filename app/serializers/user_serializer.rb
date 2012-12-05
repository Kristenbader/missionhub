class UserSerializer < ActiveModel::Serializer

  attributes :id, :username, :locale, :primary_organization_id, :time_zone, :created_at, :updated_at
  
  def primary_organization_id
    object.primary_organization_id
  end
  
    def time_zone
    object.time_zone
  end

end

