FactoryGirl.define do
  factory :person
end

FactoryGirl.define do
  factory :user do
		name "user"
		uid 1
		provider "twitter"
	end

  factory :market do
		user
		name "market"
		people_count 3
		evaluation_parameter 100000
		initial_self_evaluation 20000
		natural_recovery_rate 1
	end

  factory :market5, class: Market do
		user
		name "market"
		people_count 5
		evaluation_parameter 100000
		initial_self_evaluation 10000
		natural_recovery_rate 1
	end
end

