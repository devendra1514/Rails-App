# frozen_string_literal: true

class Admin < ApplicationRecord
  # Stateful Session Auth (Do NOT include :jwt_authenticatable)
  devise :database_authenticatable, :validatable,
         :timeoutable, :lockable, :trackable, :recoverable,
         timeout_in: 15.minutes,         # Session timeout (inactivity)
         maximum_attempts: 3,            # Strict lockout
         unlock_strategy: :email         # Unlock via email link

  # Enforce enterprise password complexity (min 12 chars, upper, lower, digit, symbol)
  validates :password,
            length: { minimum: 12 },
            format: {
              with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^a-zA-Z\d]).+\z/,
              message: "must include at least one uppercase letter, one lowercase letter, one number, and one special character"
            },
            if: :password_required?

  # Ransack allowlist for ActiveAdmin filtering (Rails 8 / Ransack 4 requirement)
  def self.ransackable_attributes(_auth_object = nil)
    %w[id email sign_in_count current_sign_in_at last_sign_in_at created_at updated_at locked_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end
end
