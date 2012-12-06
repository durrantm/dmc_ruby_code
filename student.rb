class Student < ActiveRecord::Base

  ADHOC_STUDENT_ID = 'Added manually'

  cattr_reader :per_page
  @@per_page = 25

  before_validation :downcase_gender! # Required in Rails 3

  with_options :unless => :adhoc? do |v|
    v.validates_presence_of :gender
    v.validates_presence_of :state_id_number
    v.validates_presence_of :student_id_number
    v.validate :student_unique_in_district
    v.validate :presence_of_school_and_classroom
  end

  # New ad hoc students cannot be saved if they share first and last name with any existing student, in a school
  validates :first_name, :uniqueness => { :scope => [:last_name, :school_id] }, :if => Proc.new { |iep| iep.adhoc? }
  validates_presence_of :first_name
  validates_presence_of :last_name
  validates_length_of :first_name, :maximum => 30
  validates_length_of :last_name, :maximum => 30
  validates_length_of :middle_name, :maximum => 30, :allow_blank => true

  with_options :allow_nil => true do |v|
    v.validates_length_of :case_manager, :maximum => 50
    v.validates_length_of :disability_category, :maximum => 100
    v.validates_length_of :program_type_code, :maximum => 10
    v.validates_length_of :special_education_classification, :maximum => 10
  end

  belongs_to :school
  belongs_to :classroom

  has_many :iep_services, :dependent => :destroy do
    def total_time
      sum('duration * frequency').to_i
    end
  end

  has_one :grade, :through => :classroom
  delegate :district, :to => :school, :prefix => true, :allow_nil => true
  enum_field :gender, ['male', 'female', 'unknown']
  default_value_for :gender, 'unknown'
  default_value_for :adhoc, false
  scope :ordered, { :order => 'last_name ASC, first_name ASC' }
  scope :specialties, { :select => "DISTINCT specialty" }

  #TODO(agraves@dmcouncil.org): figure out wtf these are used for
  # and name them something helpful
  scope :for_schedule_show, :select => 'students.id as student_id, '\
    'school_id, first_name, last_name', :order => 'last_name ASC'

  def self.official
    where("adhoc = FALSE")
  end

  def self.number_of_official_students
    official.count
  end

  def district_id
#    self.school ? self.school.district_id : nil
    school.try(:district_id)
  end

  def self.adhoc
    where("adhoc = TRUE")
  end

  # If there is an ad hoc service, return it.
  # Otherwise, create one (as a side-effect) and return it.
  # Might be better named, "find_or_create_adhoc_service."
  def adhoc_service
    result = raw_adhoc_service

    unless result
      result = IepService.new(:adhoc => true)
      iep_services << result
    end

    result
  end

  # TODO DRY this up along with Attendee.moniker
  def moniker
    "#{first_name} #{last_name.strip[0, 1]}."
  end

  def grade_name
    adhoc? ? '*' : grade.try(:name)
  end

  def grade_level
    adhoc? ? '*' : grade.try(:level)
  end

  def school_name
    school.try(:name)
  end

  def classroom_name
    adhoc? ? '*' : (classroom.try(:name) || 'Unknown')
  end

  def presence_of_school_and_classroom
    if school.present? && classroom.present? && !school.classrooms.include?(classroom)
      actual_school_name = classroom.school.try(:name)
      errors.add(:classroom, "Classroom #{classroom.teacher} not defined for school #{school.name} (see school #{actual_school_name})")
    else
      school.present? or errors.add(:school, "can't be blank")
      classroom.present? or errors.add(:classroom, "can't be blank")
    end
  end

  def student_unique_in_district
    if school_district.present? && school_district.has_student_with_state_id_number?(state_id_number)
      if new_record?
        errors.add(:state_id_number, "Cannot save new student #{self} because state id number already used in #{school_district.name}")
      elsif state_id_number_changed?
        errors.add(:state_id_number, "Cannot change student's state id number to #{state_id_number} because that is already used in #{school_district.name}")
      end
    end
  end

  def specialty=(string)
    if string
      string.strip! # remember, Ruby params are passed by value
    end

    write_attribute(:specialty, string)
  end

  def to_schedule_object
    {
      'name' => full_name,
      'student_id' => id
    }
  end

  def to_s
    "#{full_name}<#{id}>"
  end

  def downcase_gender!
    gender.try :downcase!
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def first_name_and_initial
    first_name + last_initial
  end

  def last_name_first_name
    "#{last_name}, #{first_name}"
  end

  def as_attendee
    Attendee.delete_by_id(id)
    attendee = Attendee.new(:attendee_id   => id,
                            :attendee_name => full_name,
                            :classroom     => classroom_name,
                            :grade         => grade_level,
                            :school_name   => school_name,
                            :specialty     => specialty)

    attendee.save
    attendee
  end

  def classroom_restrictions
    classroom.try(:restrictions) || []
  end

  def grade_restrictions_for_school(id)
    if grade
      grade.restrictions.for_school(school_id)
    else
      []
    end
  end

  def schoolwide_restrictions
    school.try(:schoolwide_restrictions) || []
  end

  # TODO private
  def classroom_and_grade_restrictions
    grade_restrictions_for_school(school_id) + classroom_restrictions
  end

  def classroom_and_grade_restrictions_on_during(day, range)
    classroom_and_grade_restrictions.select {|r| r.overlap_on?(range, day)}
  end

  # TODO This is dubiously useful.  Class and grade restrictions apply to a student,
  # whereas school-wide restrictions apply only to the therapists.
  def restrictions
    classroom_and_grade_restrictions + schoolwide_restrictions
  end

  def iep_services_to_requirements_effective_for(schedule_parameters)
    iep_services.collect {|ieps| ieps.as_requirement_effective_for(schedule_parameters)}
  end

  # TODO Move to module describing StudentsController-related functionality
  def student_index_presenter
    keys = [:grade_name, :classroom_name, :student_id_number, :specialty, :disability]
    result = Hash.new

    keys.each do |key|
      result[key] = self.send(key)
    end
  end

  private

  def raw_adhoc_service
    iep_services.where(:adhoc => true).first
  end

  def last_initial
    last_name.empty? ? "" : " #{last_name.first}."
  end
end
