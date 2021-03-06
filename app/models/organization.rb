require 'name_uniqueness_validator'

class Organization < ActiveRecord::Base
  attr_accessor :person_id

  has_ancestry

  belongs_to :importable, polymorphic: true
  has_many :roles, inverse_of: :organization
  has_many :group_labels
  has_many :activities, dependent: :destroy
  has_many :target_areas, through: :activities, class_name: 'TargetArea'
  has_many :people, through: :organizational_roles, conditions: ["organizational_roles.deleted = 0"], uniq: true
  has_many :not_archived_people, through: :organizational_roles, source: :person, conditions: ["organizational_roles.deleted = 0 AND archive_date is NULL"], uniq: true
  has_many :contact_assignments
  has_many :keywords, class_name: 'SmsKeyword'
  has_many :surveys, dependent: :destroy
  has_many :survey_elements, through: :surveys
  has_many :questions, through: :surveys
  has_many :all_questions, through: :surveys, source: :all_questions
  has_many :followup_comments
  has_many :organizational_roles, inverse_of: :organization
  has_many :non_deleted_people, through: :organizational_roles, source: :person, conditions: ["organizational_roles.deleted = ?", 0], uniq: true
  has_many :leaders, through: :organizational_roles, source: :person, conditions: ["organizational_roles.role_id IN (?) AND organizational_roles.deleted = ? AND organizational_roles.archive_date IS NULL", Role.leader_ids, 0], order: "people.last_name, people.first_name", uniq: true
  has_many :only_leaders, through: :organizational_roles, source: :person, conditions: ["organizational_roles.role_id = ? AND organizational_roles.deleted = ? AND organizational_roles.archive_date IS NULL", Role::LEADER_ID, 0], order: "people.last_name, people.first_name", uniq: true
  has_many :admins, through: :organizational_roles, source: :person, conditions: ["organizational_roles.role_id = ? AND organizational_roles.deleted = ? AND organizational_roles.archive_date IS NULL", Role::ADMIN_ID, 0], order: "people.last_name, people.first_name", uniq: true
  has_many :all_people, through: :organizational_roles, source: :person, conditions: ["organizational_roles.followup_status <> 'do_not_contact' AND organizational_roles.deleted = 0 AND organizational_roles.archive_date IS NULL"]
  has_many :all_people_with_archived, through: :organizational_roles, source: :person, conditions: ["organizational_roles.followup_status <> 'do_not_contact' AND organizational_roles.deleted = 0"]
  has_many :contacts, through: :organizational_roles, source: :person, conditions: ["organizational_roles.role_id = ? AND organizational_roles.archive_date IS NULL AND organizational_roles.followup_status <> 'do_not_contact' AND organizational_roles.deleted = 0", Role::CONTACT_ID]
  has_many :contacts_with_archived, through: :organizational_roles, source: :person, conditions: ["organizational_roles.role_id = ? AND organizational_roles.followup_status <> 'do_not_contact' AND organizational_roles.deleted = 0", Role::CONTACT_ID]
  has_many :dnc_contacts, through: :organizational_roles, source: :person, conditions: ["organizational_roles.archive_date IS NULL AND organizational_roles.followup_status = 'do_not_contact'"]
  has_many :completed_contacts, through: :organizational_roles, source: :person, conditions: ["organizational_roles.role_id = ? AND organizational_roles.deleted = ? AND organizational_roles.archive_date IS NULL AND organizational_roles.followup_status = ?", Role::CONTACT_ID, 0, 'completed']
  has_many :no_activity_contacts, through: :organizational_roles, source: :person, conditions: ["organizational_roles.role_id = ? AND organizational_roles.deleted = ? AND organizational_roles.archive_date IS NULL AND organizational_roles.followup_status = ?", Role::CONTACT_ID, 0, 'uncontacted']
  has_many :rejoicables
  has_many :groups
  has_one :api_client, class_name: 'Rack::OAuth2::Server::Client', inverse_of: :organization
  belongs_to :conference, class_name: 'Ccc::Crs2Conference', foreign_key: 'conference_id'

  Rejoicable::OPTIONS.each do |option|
    has_many :"#{option}_contacts", :through => :rejoicables, source: :person, conditions: {'rejoicables.what' => option}, uniq: true
  end

  default_value_for :show_sub_orgs, true

  validates_presence_of :name, :terminology#, :person_id
  validates :name, :name_uniqueness => true

  @queue = :general
  after_create :create_admin_user, :notify_admin_of_request

  serialize :settings, Hash

  state_machine :status, initial: :requested do
    state :requested
    state :active
    state :denied
    state :inactive

    event :approve do
      transition :requested => :active
    end
    after_transition :on => :approve, :do => :notify_user

    event :deny do
      transition :requested => :denied
    end
    after_transition :on => :deny, :do => :notify_user_of_denial

    event :disable do
      transition any => :inactive
    end
  end

  def is_root? # an org is considered root if it has no parents
    ancestry.nil? || !parent.show_sub_orgs
  end

  def is_child?
    !ancestry.nil?
  end

  def is_root_and_has_only_one_admin?
    (ancestry.nil? || !parent.show_sub_orgs ) && admins.count == 1
  end

  def to_s() name; end

  def parent_organization
    org = Organization.find(ancestry.split('/').last) if ancestry.present?
    return org if org.present?
  end

  def parent_organization_admins
    #returns own admins plus the all the admins of all the ancestor organizations
    if ancestry.nil? || !parent.show_sub_orgs
      return admins
    else
      return parent.parent_organization_admins + admins
    end
  end

  def all_possible_admins
    admins.present? ? admins : parent_organization_admins
  end

  def all_possible_admins_with_email
    all_admins = all_possible_admins
    if all_admins.present?
      admins_with_email = Array.new
      all_admins.each do |admin|
        admins_with_email << admin if admin.email.present?
      end
      return admins_with_email
    end
  end

  def self_and_children
    [self] + children
  end

  def self_and_descendant_ids
    [id] + descendant_ids
  end

  # def children_surveys
  #   Survey.where(organization_id: child_ids)
  # end

  def active_keywords
    keywords.where(state: 'active')
  end

  def self_and_children_ids
    @self_and_children_ids ||= [id] + child_ids
  end

  def self_and_children_surveys
    Survey.where(organization_id: self_and_children_ids)
  end

  def self_and_children_keywords
    SmsKeyword.where(organization_id: self_and_children_ids)
  end

  def self_and_children_questions
    @self_and_children_questions ||= self_and_children_surveys.collect(&:questions).flatten.uniq
  end

  def unassigned_contacts
    person_table_pkey = "#{Person.table_name}.#{Person.primary_key}"
    Person
    .joins("INNER JOIN organizational_roles org_roles ON org_roles.person_id = #{person_table_pkey}
        AND org_roles.organization_id = #{id}
        AND org_roles.role_id = '#{Role::CONTACT_ID}'
        AND org_roles.followup_status <> 'do_not_contact'
        AND org_roles.followup_status <> 'completed'
        AND org_roles.archive_date IS NULL
        AND org_roles.deleted = 0
        LEFT JOIN contact_assignments ca ON ca.person_id = #{person_table_pkey}
        AND ca.organization_id = #{id}")
        .where("ca.id IS NULL OR ca.assigned_to_id NOT IN (?)", only_leaders)
  end

  def inprogress_contacts
    person_table_pkey = "#{Person.table_name}.#{Person.primary_key}"
    Person
    .joins("INNER JOIN organizational_roles ON organizational_roles.person_id = #{person_table_pkey}
        AND organizational_roles.organization_id = #{id}
        AND organizational_roles.role_id = '#{Role::CONTACT_ID}'
        AND followup_status <> 'do_not_contact'
        AND followup_status <> 'completed'
        AND archive_date IS NULL
        AND deleted = 0
        LEFT JOIN contact_assignments ON contact_assignments.person_id = #{person_table_pkey}
        AND contact_assignments.organization_id = #{id}")
        .where("contact_assignments.assigned_to_id IN (?)", only_leaders)
  end

  def roles
    Role.where("organization_id = 0 or organization_id = #{id}")
  end

  def <=>(other)
    name <=> other.name
  end

  def validation_method_enum # ???
    ['relay']
  end

  def terminology_enum
    Organization.connection.select_values("select distinct(terminology) term from organizations order by term")
  end

  def name_with_keyword_count
    "#{name} (#{keywords.count})"
  end

  def add_role_to_person(person, role_id)
    person_id = person.is_a?(Person) ? person.id : person
    role = OrganizationalRole.where(person_id: person_id, organization_id: id, role_id: role_id).first_or_create!
    role.update_attributes(end_date: nil, archive_date: nil, deleted: 0)
    role
  end

  def remove_role_from_person(person, role_id)
    person_id = person.is_a?(Person) ? person.id : person
    OrganizationalRole.where(person_id: person_id, organization_id: id, role_id: role_id).each { |r| r.update_attributes(deleted: true, end_date: Time.now) }
  end

  def add_leader(person, current_person)
    person_id = person.is_a?(Person) ? person.id : person
    begin
      org_leader = OrganizationalRole.find_or_create_by_person_id_and_organization_id_and_role_id(person_id, id, Role::LEADER_ID, :added_by_id => current_person.id)
      unless org_leader.archive_date.nil?
        org_leader.update_attributes({:added_by_id => current_person.id, :archive_date => nil})
        org_leader.notify_new_leader
      end
    rescue => error
      @save_retry_count =  (@save_retry_count || 5)
      retry if( (@save_retry_count -= 1) > 0 )
      raise error
    end
  end

  def add_contact(person)
    begin
      add_role_to_person(person, Role::CONTACT_ID)
    rescue => error
      @save_retry_count =  (@save_retry_count || 5)
      retry if( (@save_retry_count -= 1) > 0 )
      raise error
    end
  end

  def add_admin(person)
    add_role_to_person(person, Role::ADMIN_ID)
  end

  def remove_person(person)
    person_id = person.is_a?(Person) ? person.id : person
    organizational_roles.where(person_id: person_id).each do |ors|
      if(ors.role_id == Role::LEADER_ID)
        # remove contact assignments if this was a leader
        Person.find(ors.person_id).contact_assignments.where(organization_id: id).all.collect(&:destroy)
      end
      remove_role_from_person(person, ors.role_id)
    end
  end

  def remove_contact(person)
    remove_role_from_person(person, Role::CONTACT_ID)
  end

  def add_involved(person)
    add_role_to_person(person, Role::INVOLVED_ID)
  end

  def remove_leader(person)
    person = person.is_a?(Person) ? person : Person.find(person)
    remove_role_from_person(person, Role::LEADER_ID)
    person.remove_assigned_contacts(self)
  end

  def move_contact(person, to_org, keep_contact, current_admin = nil)
    @followup_comments = followup_comments.where(contact_id: person.id)
    @rejoicables = rejoicables.where(person_id: person.id)
    if keep_contact == "false"
      remove_person(person)
      # move call followup comments
      @followup_comments.update_all(organization_id: to_org.id)
      @rejoicables.update_all(organization_id: to_org.id)
    else
      # copy followup comments
      @followup_comments.each do |fc|
        to_org.followup_comments.create(fc.attributes.slice(:contact_id, :commenter_id, :status, :comment, :updated_at, :created_at, :deleted_at))
        @rejoicables.where(followup_comment_id: fc.id).each do |r|
          to_org.rejoicables.create(r.attributes.slice(:person_id, :created_by_id, :what, :updated_at, :created_at, :deleted_at))
        end
      end
    end

    to_org.add_contact(person)

    # Save transfer log
    val_copy = keep_contact == "false" ? false : true
    val_transferred_by = current_admin.id if current_admin.present?
    PersonTransfer.create(person_id: person.id, old_organization_id: id, new_organization_id: to_org.id, transferred_by_id: val_transferred_by, copy: val_copy)

    FollowupComment.where(organization_id: id, contact_id: person.id).update_all(organization_id: to_org.id)
  end

  def create_admin_user
    add_admin(Person.find(self.person_id)) if person_id
  end

  def notify_admin_of_request
    begin
      if parent
        update_column(:status, 'active')
      else
        OrganizationMailer.enqueue.notify_admin_of_request(self.id)
      end
    rescue ActiveRecord::RecordNotFound
    end
  end

  def notify_new_leader(person, added_by)
    token = SecureRandom.hex(12)
    person.user.remember_token = token
    person.user.remember_token_expires_at = 1.month.from_now
    person.user.save(validate: false)
    LeaderMailer.added(person, added_by, self, token).deliver
  end

  def attempting_to_delete_or_archive_all_the_admins_in_the_org?(ids)
    admin_ids = parent_organization_admins.collect(&:id)
    i = admin_ids & ids.collect(&:to_i)
    return i if (admin_ids - i).blank?
    false
  end

  def attempting_to_delete_or_archive_current_user_self_as_admin?(ids, current_person)
    return true unless ([current_person.id] & ids.collect(&:to_i)).blank?
    false
  end

  def queue_import_from_conference(user)
    async(:import_from_conference, user.id)
  end

  private

  def import_from_conference(user_id)
    user = User.find(user_id)

    CrsImport.new(self, user).import
  end

  def notify_user
    if admins
      OrganizationMailer.enqueue.notify_user(id)
    end
    true
  end

  def notify_user_of_denial
    if admins
      OrganizationMailer.enqueue.notify_user_of_denial(id)
    end
    true
  end

end
