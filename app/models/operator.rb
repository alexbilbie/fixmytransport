# == Schema Information
# Schema version: 20100707152350
#
# Table name: operators
#
#  id              :integer         not null, primary key
#  code            :string(255)
#  name            :text
#  created_at      :datetime
#  updated_at      :datetime
#  short_name      :string(255)
#  email           :text
#  email_confirmed :boolean
#  notes           :text
#

class Operator < ActiveRecord::Base

  # This model is part of the transport data that is versioned by data generations.
  # This means they have a default scope of models valid in the current data generation.
  # See lib/fixmytransport/data_generations
  exists_in_data_generation( :identity_fields => [:noc_code],
                             :new_record_fields => [:name, :transport_mode_id],
                             :update_fields => [:vosa_license_name,
                                                :parent,
                                                :ultimate_parent,
                                                :vehicle_mode],
                             :temporary_identity_fields => [:id],
                             :auto_update_fields => [:cached_slug])

  has_many :route_operators, :dependent => :destroy
  has_many :routes, :through => :route_operators, :uniq => true, :order => 'routes.number asc'
  has_many :vosa_licenses
  has_many :operator_codes
  has_many :stop_area_operators, :dependent => :destroy
  has_many :stop_areas, :through => :stop_area_operators, :dependent => :destroy, :uniq => true
  belongs_to :transport_mode
  validates_presence_of :name
  validate :noc_code_unique_in_generation
  has_many :operator_contacts, :conditions => ['deleted = ?', false],
                               :foreign_key => :operator_persistent_id,
                               :primary_key => :persistent_id
  has_many :responsibilities, :as => :organization
  accepts_nested_attributes_for :route_operators, :allow_destroy => true, :reject_if => :route_operator_invalid
  has_paper_trail :meta => { :replayable  => Proc.new { |operator| operator.replayable } }
  cattr_reader :per_page
  @@per_page = 20
  named_scope :with_email, :conditions => ["email is not null and email != ''"]
  named_scope :without_email, :conditions => ["email is null or email = ''"]
  has_friendly_id :name, :use_slug => true

  # this is a custom validation as noc codes need only be unique within the data generation bounds
  # set by the default scope. Allows blank values
  def noc_code_unique_in_generation
    self.field_unique_in_generation(:noc_code)
  end

  # we only accept new or delete existing associations
  def route_operator_invalid(attributes)
    (attributes['_add'] != "1" and attributes['_destroy'] != "1") or attributes['route_id'].blank?
  end

  def emailable?(location)
    general_contacts = self.operator_contacts.find(:all, :conditions => ["category = 'Other'
                                                                          AND (location_persistent_id is null
                                                                          OR (location_persistent_id = ?
                                                                          AND location_type = ?))",
                                                                          location.persistent_id, location.class.to_s])
    return false if general_contacts.empty?
    return true
  end

  def contacts_for_location(location)
    self.operator_contacts.find(:all, :conditions => ['location_persistent_id = ?
                                                       AND location_type = ?',
                                                       location.persistent_id, location.class.to_s])
  end

  def general_contacts
    self.operator_contacts.find(:all, :conditions => ["location_persistent_id is null
                                                       AND (location_type is null
                                                       OR location_type = '')"])
  end

  def codes
    operator_codes.map{ |operator_code| operator_code.code }.uniq
  end

  def categories(location)
    contacts = self.contacts_for_location(location)
    if contacts.empty?
      contacts = self.general_contacts
    end
    contacts.map{ |contact| contact.category }
  end

  def contact_for_category(contact_list, category)
    contact_list.detect{ |contact| contact.category == category }
  end

  # return the appropriate contact for a particular type of problem
  def contact_for_category_and_location(category, location, exception_on_fail=true)
    location_contacts = self.contacts_for_location(location)
    if category_contact = contact_for_category(location_contacts, category)
      return category_contact
    elsif other_contact = contact_for_category(location_contacts, "Other")
      return other_contact
    else
      general_contacts = self.general_contacts
      if category_contact = contact_for_category(general_contacts, category)
        return category_contact
      elsif other_contact = contact_for_category(general_contacts, "Other")
        return other_contact
      else
        if exception_on_fail
          raise "No \"Other\" category contact for #{self.name} (operator ID: #{self.id})"
        else
          return nil
        end
      end
    end
  end

  def emails
    self.operator_contacts.map{ |contact| contact.email }.uniq.compact
  end

  def self.count_without_contacts
    count(:conditions => ['persistent_id not in (select operator_persistent_id from operator_contacts where deleted = ?)', false])
  end

  def self.find_all_by_nptdr_code(transport_mode, code, region, route)
    operators = find(:all, :include => :operator_codes,
                           :conditions => ['transport_mode_id = ?
                                            AND operator_codes.code = ?
                                            AND operator_codes.region_id = ?',
                                            transport_mode, code, region])
    # try specific lookups
    if operators.empty?
      if transport_mode.name == 'Train'
        operators = find(:all, :conditions => ["transport_mode_id = ?
                                                AND noc_code = ?", transport_mode, "=#{code}"])
      end
      #  There's a missing trailing number from Welsh codes ending in '00' in 2009 and 2010 NPTDR
      if /[A-Z][A-Z]00/.match(code) and transport_mode.name == 'Bus'
        # find any code in the region that consists of the truncated code plus one other character
        code_with_wildcard = "#{code}_"
        operators = find(:all, :conditions => ["transport_mode_id = ?
                                                AND operator_codes.code like ?
                                                AND region_id = ?",
                                                transport_mode, code_with_wildcard, Region.find_by_name('Wales')],
                               :include => :operator_codes)
      end
    end

    if operators.empty?
      # if no operators, add any operators with this code with the right transport_mode in a region the route
      # goes through
      regions = route.stops.map{ |stop| stop.locality.admin_area.region }.uniq
      operators = find(:all, :conditions => ["transport_mode_id = ?
                                              AND operator_codes.code = ?
                                              AND region_id in (?)",
                                              transport_mode, code, regions],
                             :include => :operator_codes)
    end
    if operators.empty?
      if similar = self.similar_mode(transport_mode)
        # look for the code in the region with a similar transport_mode
        operators = find(:all, :conditions => ["transport_mode_id = ?
                                                AND operator_codes.code = ?
                                                AND region_id = ?",
                                                similar, code, region],
                               :include => :operator_codes)
      end
    end

    # # try any operators with that code
    if (transport_mode.name == 'Train' || transport_mode.name == 'Coach') && operators.empty?
      operators = find(:all, :include => :operator_codes,
                             :conditions => ['transport_mode_id = ?
                                              AND operator_codes.code = ?',
                                              transport_mode, code])
    end
    operators
  end

  def self.vehicle_mode_to_transport_mode(vehicle_mode)
    modes_to_modes = {  'bus'         => 'Bus',
                        'coach'       => 'Coach',
                        'drt'         => 'Bus',
                        'ferry'       => 'Ferry',
                        'metro'       => 'Tram/Metro',
                        'other'       => 'Bus',
                        'rail'        => 'Train',
                        'tram'        => 'Tram/Metro',
                        'underground' => 'Tram/Metro' }
    TransportMode.find_by_name(modes_to_modes[vehicle_mode.downcase])
  end

  def self.similar_mode(transport_mode)
    similar = { 'Bus' => 'Coach',
                'Coach' => 'Bus' }
    if similar_mode_name = similar[transport_mode.name]
      return TransportMode.find_by_name(similar_mode_name)
    else
      return nil
    end
  end

  # merge operator records to merge_to, transferring associations
  def self.merge!(merge_to, operators)
    transaction do
      operators.each do |operator|
        next if operator == merge_to
        operator.route_operators.each do |route_operator|
          merge_to.route_operators.build(:route => route_operator.route)
        end
        if !operator.email.blank? and merge_to.email.blank?
          merge_to.email = operator.email
          merge_to.email_confirmed = operator.email_confirmed
        end
        operator.destroy
      end
      merge_to.save!
    end
  end

  def self.problems_at_location(location_type, location_persistent_id, operator_id)
    conditions = ["problems.location_type = ?
                   AND problems.location_persistent_id = ?
                   AND responsibilities.organization_id = ?
                   AND responsibilities.organization_type = 'Operator'",
                  location_type, location_persistent_id, operator_id]
    return Problem.find(:all, :conditions => conditions, :include => :responsibilities)
  end

  def self.all_by_letter
    MySociety::Util.by_letter(Operator.find(:all), :upcase){|o| o.name }
  end

  def self.all_letters
    all_by_letter.keys.sort
  end

  # slightly ugly syntax for class methods
  class << self; extend ActiveSupport::Memoizable; self; end.memoize :all_by_letter, :all_letters

end
