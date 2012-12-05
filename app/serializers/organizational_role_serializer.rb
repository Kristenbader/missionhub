class OrganizationalRoleSerializer < ActiveModel::Serializer

  attributes :id, :followup_status, :role_id, :person_id, :organization_id,
             :start_date, :archive_date, :deleted, :updated_at, :created_at

end

