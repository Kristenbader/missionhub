class UserSerializer < ActiveModel::Serializer

  attributes :id, :username, :locale, :person_id, :primary_organization_id, :time_zone, :created_at, :updated_at
  
  def person_id 
    object.person.id
  end
  
  def primary_organization_id
    object.primary_organization_id
  end
  
  def time_zone
    object.time_zone
  end

end

