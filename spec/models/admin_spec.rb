# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin, type: :model do
  subject(:admin) { build(:admin) }

  describe "validations" do
    it "has a valid factory" do
      expect(admin).to be_valid
    end

    it "requires email presence" do
      admin.email = nil
      expect(admin).not_to be_valid
      expect(admin.errors[:email]).to be_present
    end

    it "enforces unique email" do
      create(:admin, email: "duplicate@example.com")
      duplicate = build(:admin, email: "duplicate@example.com")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to be_present
    end

    it "rejects passwords shorter than 12 characters" do
      admin.password = "Short1!#"
      admin.password_confirmation = "Short1!#"
      expect(admin).not_to be_valid
      expect(admin.errors[:password]).to include("is too short (minimum is 12 characters)")
    end

    it "rejects passwords without a special character" do
      admin.password = "Password12345"
      admin.password_confirmation = "Password12345"
      expect(admin).not_to be_valid
      expect(admin.errors[:password]).to be_present
    end

    it "rejects passwords without a digit" do
      admin.password = "PasswordSpecial!#"
      admin.password_confirmation = "PasswordSpecial!#"
      expect(admin).not_to be_valid
      expect(admin.errors[:password]).to be_present
    end

    it "accepts strong passwords meeting all complexity criteria" do
      admin.password = "ValidAdminSecret123!#"
      admin.password_confirmation = "ValidAdminSecret123!#"
      expect(admin).to be_valid
    end
  end

  describe "Devise modules" do
    it "configures timeoutable to 15 minutes" do
      expect(described_class.timeout_in).to eq(15.minutes)
    end

    it "configures lockable maximum attempts to 3" do
      expect(described_class.maximum_attempts).to eq(3)
    end

    it "configures lockable unlock strategy to email" do
      expect(described_class.unlock_strategy).to eq(:email)
    end
  end

  describe "Ransack allowlists" do
    it "exposes safe attributes for ActiveAdmin search and filtering" do
      allowed = described_class.ransackable_attributes
      expect(allowed).to include("email", "sign_in_count", "current_sign_in_at", "locked_at")
      expect(allowed).not_to include("encrypted_password", "reset_password_token", "unlock_token")
    end

    it "exposes empty array for ransackable associations" do
      expect(described_class.ransackable_associations).to eq([])
    end
  end
end
