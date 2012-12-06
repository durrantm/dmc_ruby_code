class StudentsController < ApplicationController
  load_and_authorize_resource :except => [:create, :new, :index]
  before_filter :current_district

  def index
    @students = Student.joins(:school).where("schools.district_id = ?", current_user.district_id).order("last_name asc, first_name asc").paginate(:page => params[:page])
    @students.each { |student|
      authorize! :read, student
    }
  end

  def new
    @student = Student.new
  end

  def show
  end

  def edit
  end

  def destroy
    #@student.destroy
    redirect_to students_path, notice: 'Students cannot currently be deleted.'
  end

  def update
    # Force this to be an ad hoc student--cannot use this controller for non-ad-hoc students
    if @student.update_attributes(params["student"].merge(:adhoc => true))
      redirect_to edit_student_path(@student),  notice: 'Student was successfully updated.'
    else
      redirect_to edit_student_path(@student),  notice: 'There was an error updating the student record.'
    end
  end

  def create
    # Force this to be an ad hoc student--cannot use this controller for non-ad-hoc students
    @student =  current_district.students.new(params["student"].merge(:adhoc => true))
    authorize! :update, @student

    if @student.save
      redirect_to students_path,  notice: 'Student was added manually.'
    else
      render action: "new", notice: 'There was an error saving the student record.'
    end
  end

end
