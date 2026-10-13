# frozen_string_literal: true

FactoryBot.define do
  factory :admin do
    sequence(:email) { |n| "admin#{n}@example.com" }
    password { "AdminSecret123!#" }
    password_confirmation { "AdminSecret123!#" }
  end
end
