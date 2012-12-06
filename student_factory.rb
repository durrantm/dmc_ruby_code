FactoryGirl.define do
  FactoryGirl.define do
    sequence :student_last_name do |n|
      "#{n}"
    end
  end

  FactoryGirl.define do
    sequence :state_id_number do |n|
      "#{n}"
    end
  end

  factory :student do
    first_name        'Andy'
    last_name         { FactoryGirl.generate :student_last_name }
    gender            'male'
    state_id_number   { FactoryGirl.generate :state_id_number }
    student_id_number '200'
    school { create(:school) }
  end

  factory :adhoc_student, class: Student do
    adhoc true
    first_name "Ad"
    last_name "Hoc"
    school { create(:school) }
  end

  # TODO: remove
  factory :student_with_required_iep, :parent => :student do
  end

  factory :alice, :parent => :student_with_required_iep do
    first_name        'Alice'
    last_name         'Anderson'
  end

  factory :betty, :parent => :student_with_required_iep do
    first_name        'Betty'
    last_name         'Belief'
  end

  factory :clarrie, :parent => :student_with_required_iep do
    first_name        'Clarrie'
  end

  factory :cindy, :parent => :student_with_required_iep do
    first_name        'Cindy'
  end

  factory :xena, :parent => :student_with_required_iep do
    first_name        'Xena'
  end
end