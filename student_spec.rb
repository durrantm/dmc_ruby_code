require 'spec_helper'

module StudentSpecHelpers
  def create_student
    create_student_requiring
  end

  def create_student_requiring(specialty = nil)
    school, classroom = create_school_classroom
    result = FactoryGirl.create(:student, :specialty => specialty, :school => school, :classroom => classroom)
    result
  end

  def create_school_classroom
    school = FactoryGirl.create(:school, :grades => Grade.all)
    classroom = FactoryGirl.create(:classroom, :school => school)
    return school, classroom
  end
end

describe Student do
  specify "Basic Rails stuff" do
    should validate_presence_of :first_name
    should validate_presence_of :last_name
    should validate_presence_of :school
    should validate_presence_of :student_id_number
    should validate_presence_of :state_id_number
    should validate_presence_of :gender
    should belong_to :school
    should belong_to :classroom
    should have_one(:grade).through(:classroom)
    should have_many :iep_services
  end
end

describe Student do
  it "Allows proper values for :gender" do
    ["male", "female", "Male", "FeMaLe", "unknown"].each do |value|
      should allow_value(value).for(:gender)
    end
  end
  #
  it "Prevents improper values for :gender" do
    ["pink", "cow", "frank"].each do |value|
      should_not allow_value(value).for(:gender)
    end
  end
end

describe "Student" do
  include StudentSpecHelpers

  context "Given a district with a student" do
    before(:each) { @student = create_student }

    context "A student not yet saved with the same state id number, in the same district" do
      before(:each) do
        @other_student = FactoryGirl.build(:student, :state_id_number => @student.state_id_number, :school => @student.school, :classroom => @student.classroom)
      end

      specify "Be invalid--cannot create a student whose state id is already in use in the district" do
        @other_student.valid?
        assert @other_student.invalid?(:state_id_number)
      end
    end
  end

  context "Given a district with a student" do
    before(:each) { @student = create_student }

    context "And another student in the same district" do
      before(:each) do
        @other_student = FactoryGirl.create(:student, :school => @student.school, :classroom => @student.classroom)
      end

      context "Changing the second student's state id to that of the first student" do
        before(:each) do
          @other_student.state_id_number = @student.state_id_number
        end

        specify "Be invalid--cannot update student's state id to something used by another student in the district" do
          @other_student.valid?
          assert @other_student.invalid?(:state_id_number)
        end
      end
    end
  end

  context "Given a district with a student" do
    before(:each) { @student = create_student }

    context "Another student" do
      before(:each) do
        @other_student = FactoryGirl.create(:student, :school => @student.school, :classroom => @student.classroom)
      end

      context "Changing something in the second student other than the state id number" do
        before(:each) do
          @other_student.last_name = "My Word"
        end

        specify "Be valid" do
          @other_student.valid?
          assert !@other_student.invalid?(:state_id_number)
        end
      end
    end
  end

  context "Given a district with a student" do
    before(:each) { @student = create_student }

    context "And another district" do
      before(:each) { @other_school, @other_classroom = create_school_classroom }

      context "A student for the second district having state id already in the first district" do
        before(:each) do
          @other_student = FactoryGirl.build(:student, :state_id_number => @student.state_id_number, :school => @other_school, :classroom => @other_classroom)
        end

        specify "Be valid--state ids are unique only within the district" do
          assert @other_student.valid?
          assert @other_student.save # concrete proof....
        end
      end
    end
  end

  context "A Student whose classroom is not in his school" do
    before(:each) do
      school = FactoryGirl.create(:school)
      classroom = FactoryGirl.create(:classroom, :school => FactoryGirl.create(:school))
      @student = FactoryGirl.build(:student, :school => school, :classroom => classroom)
    end

    specify "Fail validation" do
      assert !@student.valid?
      assert @student.invalid?(:classroom)
    end
  end

  context 'A Student with a few iep_services' do
    before(:each) do
      school = FactoryGirl.create(:school)
      classroom = FactoryGirl.create(:classroom, :school => school)
      @student = FactoryGirl.create(:student, :school => school, :classroom => classroom)
      3.times.collect{ FactoryGirl.create(:iep_service, :duration => 30, :frequency => 2, :student => @student) }
    end

    specify 'calculate the total time across the association correctly' do
      assert_equal 180, @student.iep_services.total_time
    end
  end

  context "default initialization" do
    specify "have a default value of 'unknown' for gender" do
      assert_equal Student.new.gender, 'unknown'
    end

    specify "have a default value of true for sped" do
      assert Student.new.sped?
    end
  end

  specify "return correct string from first_name_and_initial" do
    student = FactoryGirl.build(:student, :first_name => "Alice", :last_name => "Pastel")
    assert_equal "Alice P.", student.first_name_and_initial
  end

  specify "return correct string from last_name_first_name" do
    student = FactoryGirl.build(:student, :first_name => 'Alice', :last_name => 'Pastel')
    assert_equal 'Pastel, Alice', student.last_name_first_name
  end

  specify "know what grade they are in through the classroom record" do
    classroom = FactoryGirl.create(:classroom)
    student   = FactoryGirl.build_stubbed(:student, :classroom => classroom)

    assert_equal classroom.grade_level, student.grade_level
  end

  specify "display a grade of nil if the student doesn't have a classroom" do
    student = FactoryGirl.build(:student)
    assert_nil student.grade_level
  end

  specify "have meaningful to_s for debugging" do
    assert FactoryGirl.build(:student).to_s.present?
  end

  context "When calling school_name" do
    specify "return the school name when they have a school" do
      student = FactoryGirl.build(:student, :school => FactoryGirl.build(:school, :name => 'Otis Elementary'))
      assert_equal 'Otis Elementary', student.school_name
    end

    specify "return nil when they don't have a school" do
      student = FactoryGirl.build(:student, :school => nil)
      assert_equal nil, student.school_name
    end
  end

  context "Classroom And Grade Restrictions On During" do
    before(:each) do
      school = FactoryGirl.create(:school)
      classroom = FactoryGirl.create(:classroom, :school => school)
      @student = FactoryGirl.create(:student, :school => school, :classroom => classroom)
      @day = 2
      @starts = TimeOfDay[10]
      @ends = TimeOfDay[11]
      @another_day_during = FactoryGirl.create(:restriction, :day => 3, :start_time => @starts.to_s, :end_time => @ends.to_s)
      @before = FactoryGirl.create(:restriction, :day => @day, :start_time => @starts.minus_minutes(1).to_s, :end_time => @starts.to_s)
      @before_and_during = FactoryGirl.create(:restriction, :day => @day, :start_time => @starts.minus_minutes(1).to_s, :end_time => @starts.plus_minutes(1).to_s)
      @during_and_after = FactoryGirl.create(:restriction, :day => @day, :start_time => @ends.minus_minutes(1).to_s, :end_time => @ends.plus_minutes(1).to_s)
      @after = FactoryGirl.create(:restriction, :day => @day, :start_time => @ends.to_s, :end_time => @ends.plus_minutes(1).to_s)
      @student.stub(:classroom_and_grade_restrictions).and_return [@before, @before_and_during, @during_and_after, @after]
      @actuals = @student.classroom_and_grade_restrictions_on_during(@day, (@starts...@ends))
    end

    specify "(Sanity) return nothing if there are no restrictions" do
      @student.stub(:classroom_and_grade_restrictions).and_return []
      assert_equal [], @student.classroom_and_grade_restrictions_on_during(2, (@starts...@ends))
    end

    specify "return precisely those restrictions overlapping the time on the day" do
      assert @actuals.include?(@before_and_during)
      assert @actuals.include?(@during_and_after)
      assert_equal 2, @actuals.size
    end
  end

  context "A specialty with leading and/or trailing spaces" do
    before(:each) { @specialty = "    oh, my      "}

    specify "Be stripped when assigned to a student" do
      student = create_student_requiring(@specialty)
      assert student.valid?
      assert_equal 'oh, my', student.specialty
    end
  end

  context "A nil specialty" do
    before(:each) { @specialty = nil }

    specify "Be a legal specialty" do
      student = create_student_requiring(@specialty)
      assert student.valid?
      assert_nil student.specialty
    end
  end

  context "Given some students" do
    before(:each) do
      create_student_requiring('Tom')
      create_student_requiring(nil)
      create_student_requiring('Harry')
      create_student_requiring('Tom')
    end

    context "The 'specialties' scope" do
      before(:each) { @specialties = Student.specialties.map(&:specialty) }

      specify "Return the unique specialties for its students" do
        assert_same_elements ["Tom", "Harry", nil], @specialties
      end
    end
  end

  context "A student with a nil (default) specialty" do
    before(:each) { @student = FactoryGirl.build(:student, :specialty => nil) }

    specify "Render itself as an attendee with a nil specialty" do
      attendee = @student.as_attendee
      assert_nil attendee.specialty
    end
  end

  context "A student with an explicit specialty" do
    before(:each) { @student = FactoryGirl.build(:student, :specialty => 'Autism') }

    specify "Render itself as an attendee with that specialty" do
      attendee = @student.as_attendee
      assert_equal 'Autism', attendee.specialty
    end
  end

  context "Given a student" do
    let!(:student) do
      classroom = FactoryGirl.build(:classroom)
      FactoryGirl.build(:student, :classroom => classroom)
    end

    describe "The classroom teacher" do
      subject { student.classroom_name }

      specify do
        should_not be_nil # make sure this test is testing something meaningful
        should == student.classroom.teacher
      end
    end
  end

  context "Given a student with no iep services" do
    let!(:student) do
      school = FactoryGirl.create(:school)
      classroom = FactoryGirl.create(:classroom, :school => school)
      FactoryGirl.create(:student, :school => school, :classroom => classroom)
    end

    context "When adhoc_service is called" do
      let!(:adhoc_service) { student.adhoc_service }

      specify "The adhoc service is created for the student" do
        adhoc_service.should_not be_nil
        adhoc_service.should be_adhoc
        student.iep_services.adhoc.should have(1).item
        student.iep_services.adhoc.first.should == adhoc_service
      end
    end
  end

  context "Given a student" do
    let!(:student) do
      school = FactoryGirl.create(:school)
      classroom = FactoryGirl.create(:classroom, :school => school)
      FactoryGirl.create(:student, :school => school, :classroom => classroom)
    end

    context "With an ad hoc iep service" do
      let!(:adhoc_service) { student.adhoc_service }

      context "A second call for the ad hoc service" do
        subject { student.adhoc_service }

        specify "Returns the same object as the original call" do
          subject.should == adhoc_service
          student.iep_services.adhoc.count.should == 1 # never more than one created per student
        end
      end
    end
  end
end
