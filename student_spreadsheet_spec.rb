require 'spec_helper'

module StudentSpreadsheetSpecHelpers
  def set_up_district
    set_up_district_named('Spreadsheet District')
  end

  def set_up_district_named(name)
    @district = FactoryGirl.create(:district, :name => name)
    @elementary = create_school("Spreadsheet Elementary", "1")
    @middle = create_school("Spreadsheet Middle", "8")
    @high = create_school("Spreadsheet High", "10")
    @district
  end

  def create_school(name, grade_name)
    grade = Grade.find_by_name(grade_name)
    FactoryGirl.create(:school, :district => @district, :name => name, :grades => [grade]).tap do |s|
      FactoryGirl.create(:classroom, :teacher => "#{name} Classroom", :grade => grade, :school => s)
    end
  end
end

describe "Student Spreadsheet" do
  include AbstractSpreadsheetSharedExamples
  before(:each) { @spreadsheet_class = StudentSpreadsheet }
  it_behaves_like "an abstract spreadsheet"
end

describe "Student Spreadsheet" do
  include StudentSpreadsheetSpecHelpers
  fixtures :grades

  context "A typical district" do
    before(:each) { set_up_district }

    context "With a Student CSV" do
      before(:each) { @spreadsheet = StudentSpreadsheet.new(@district, open_spec_fixture_file('sample-students.csv')) }

      specify "create students" do
        expectations = [
          ["A", nil, "Student", "101", "BCS-1", @elementary, @elementary.classrooms.first, 'male', 'Autism'],
          ["B", 'B', "Student", "102", "BCS-2", @elementary, @elementary.classrooms.first, 'male', 'Autism'],
          ["C", nil, "Student", "103", "BCS-3", @middle, @middle.classrooms.first, 'female', 'ESL'],
          ["D", nil, "Student", "104", "BCS-4", @high, @high.classrooms.first, 'female', nil]
        ]

       assert_same_elements(expectations,
          Student.all.map {|s|
            [s.first_name, s.middle_name, s.last_name, s.student_id_number, s.state_id_number, s.school, s.classroom, s.gender, s.specialty]}
        )
      end
    end
  end

  context "A typical district" do
    before(:each) { set_up_district }

    context "With a Student CSV containing errors" do
      before(:each) { @spreadsheet = StudentSpreadsheet.new(@district, open_spec_fixture_file('incorrect-data-in-students.csv')) }

      specify "Prevent importing" do
        # Leave database untouched
        assert Student.count.zero?
        assert IepService.count.zero?

        # Provide error report
        assert @spreadsheet.error_report.any?
      end
    end
  end

  context "Given a typical district" do
    before(:each) { set_up_district }

    context "With a pre-existing student" do
      before(:each) do
        @student = FactoryGirl.create(:student,
          :first_name => 'C', :last_name => 'Student',
          :student_id_number => '103', :state_id_number => 'BCS-3',
          :school => @middle, :classroom => @middle.classrooms.first
        )
      end

      context "Importing data for a student with the same state id number" do
        before(:each) do
          @string =
          "staffsmart,1,,,,,,,
          district,Spreadsheet District,,,,,,,

          line,first_name,middle_name,last_name,student_id_number,state_id_number,school,classroom,gender,race
          3,C,,Student,103,BCS-3,Spreadsheet Middle,Spreadsheet Middle Classroom,female,C
          4,D,,Student,104,BCS-4,Spreadsheet Middle,Spreadsheet Middle Classroom,female,C" # This one is OK

          @spreadsheet = StudentSpreadsheet.new(@district, @string)
        end

        specify "Fail, because state ids must be unique within a district" do
          # Database unchanged
          assert_equal 1, Student.count
          assert_equal @student[:state_id_number], Student.first[:state_id_number]
          assert_equal @student, Student.first

          # Errors
          assert @spreadsheet.errors.any?
        end
      end
    end
  end

  context "Given a typical district" do
    before(:each) do
      @elsewhere = set_up_district_named("Elsewhere")
      @elsewhere_middle = @middle
    end

    context "With a pre-existing student" do
      before(:each) do
        @student = FactoryGirl.create(:student,
          :first_name => 'C', :last_name => 'Student',
          :student_id_number => '103', :state_id_number => 'BCS-3',
          :school => @elsewhere_middle, :classroom => @elsewhere_middle.classrooms.first
        )
      end

      context "And another district with no students" do
        before(:each) { set_up_district }

        context "Importing a student to the second district with a state id from the first district" do
          before(:each) do
            @string =
            "staffsmart,1,,,,,,,
            district,Spreadsheet District,,,,,,,

            line,first_name,middle_name,last_name,student_id_number,state_id_number,school,classroom
            3,C,,Student,103,BCS-3,Spreadsheet Middle,Spreadsheet Middle Classroom
            4,D,,Student,104,BCS-4,Spreadsheet Middle,Spreadsheet Middle Classroom" # This one is OK

            @spreadsheet = StudentSpreadsheet.new(@district, @string)
          end

          specify "create students" do

            assert @spreadsheet.errors.empty?

            expectations = [
              ["C", nil, "Student", "103", "BCS-3", @middle, @middle.classrooms.first],
              ["D", nil, "Student", "104", "BCS-4", @middle, @middle.classrooms.first]
            ]

            actuals =
              Student.all.map do |s|
                [s.first_name, s.middle_name, s.last_name, s.student_id_number, s.state_id_number, s.school, s.classroom]
            end

            expectations.each do |expected|
              assert actuals.include?(expected)
            end

            assert actuals.include?(["C", nil, "Student", "103", "BCS-3", @elsewhere_middle, @elsewhere_middle.classrooms.first])
          end
        end
      end
    end
  end

  def student_attributes(s)

  end

  context "A typical district" do
    before(:each) { set_up_district }

    context "And a CSV with student referring to a school or classroom out the district" do
      before(:each) do
        another_district = FactoryGirl.create(:district)
        another_school = FactoryGirl.create(:school, :district => another_district)
        # Classroom in school in other district--same name as classroom in our district!
        another_classroom = FactoryGirl.create(:classroom, :school => another_school, :teacher => "Spreadsheet Elementary Classroom")
        @string =
"staffsmart,1,,,,,,,
district,Spreadsheet District,,,,,,,

line,first_name,middle_name,last_name,student_id_number,state_id_number,school,classroom,gender,race
1,A,,Student,101,BCS-1,#{another_school.name},Spreadsheet Elementary Classroom,male,A
2,B,B,Student,102,BCS-2,Spreadsheet Elementary,Spreadsheet High Classroom,male,B
3,C,,Student,103,BCS-3,Spreadsheet Middle,Spreadsheet Middle Classroom,female,C" # this line is OK
      end

      context "When imported" do
        before(:each) { @spreadsheet = StudentSpreadsheet.new(@district, @string) }

        specify "Fail without changing the database" do
          # Database unchanged
          assert Student.count.zero?

          # Errors
          assert @spreadsheet.errors[1].any?
          assert @spreadsheet.errors[2].any?
        end
      end
    end
  end
end
