class PhoneNumberSerializer < ActiveModel::Serializer

  attributes :id, :person_id, :number, :location, :txt_to_email, :email_updated_at, :created_at, :updated_at

end

