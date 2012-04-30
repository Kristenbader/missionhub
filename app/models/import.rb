require 'csv'
require 'open-uri'
class Import < ActiveRecord::Base
  self.table_name = 'mh_imports'

  serialize :headers
  serialize :header_mappings

  belongs_to :user
  belongs_to :organization

  has_attached_file :upload, s3_credentials: 'config/s3.yml', s3_permissions: :private, bucket: 'dev',
                             path: 'mh/imports/:attachment/:id/:filename', s3_storage_class: :reduced_redundancy

  before_save :parse_headers

  def get_new_people # generates array of Person hashes
    new_people = Array.new

    csv = CSV.readlines(upload.path)
    csv.shift #skip headers

    csv.each do |row|
      person_hash = Hash.new
      person_hash[:person] = Hash.new
      person_hash[:person][:firstName] = row[header_mappings.invert[Element.where(:attribute_name => "firstName").first.id.to_s].to_i]

      answers = Hash.new

      header_mappings.keys.each do |k|
        answers[header_mappings[k].to_i] = row[k.to_i]
      end

      person_hash[:answers] = answers
      puts person_hash
      new_people << person_hash
    end

  new_people

  end

  def check_for_errors # validating csv
    errors = []

    unless header_mappings.values.include?(Element.where( :attribute_name => "firstName").first.id.to_s) #since first name is required for every contact. Look for id of element where attribute_name = 'firstName' in the header_mappings.
      return errors << I18n.t('contacts.import_contacts.present_firstname')
    end
  end

  class NilColumnHeader < StandardError

  end

  private

  def parse_headers
    return unless upload?
    tempfile = upload.queued_for_write[:original]
    unless tempfile.nil?
      csv = CSV.new(tempfile, :headers => :first_row)
=begin
      puts upload.path
      CSV.foreach("mh/imports/uploads/82/sample_(copy).csv") do |row|
        self.headers = row
        break
      end
=end
      csv.shift
      raise NilColumnHeader if csv.headers.include?(nil)
      self.headers = csv.headers
    end
  end

  def is_row_blank?(row)
    #checking if a row has no entries (because of the possibility of user entering in a blank row in a csv file)
    row.each do |r|
      return false if !r.nil?
    end
    true
  end
end
