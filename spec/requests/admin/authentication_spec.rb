# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin Authentication and Security", type: :request do
  let!(:admin) { create(:admin, email: "superadmin@example.com", password: "AdminSecret123!#", password_confirmation: "AdminSecret123!#") }

  describe "GET /admin (Unauthenticated)" do
    it "redirects unauthenticated requests to the admin login page" do
      get "/admin"
      expect(response).to redirect_to("/admin/login")
    end
  end

  describe "POST /admin/login" do
    it "authenticates successfully with valid credentials" do
      post "/admin/login", params: {
        admin: { email: admin.email, password: "AdminSecret123!#" }
      }
      expect(response).to redirect_to("/admin")
      follow_redirect!
      expect(response.body).to include("Dashboard")
    end

    it "rejects invalid credentials and increments failed_attempts" do
      post "/admin/login", params: {
        admin: { email: admin.email, password: "WrongPassword123!#" }
      }
      expect(response).to have_http_status(:unprocessable_content).or have_http_status(:ok)
      expect(admin.reload.failed_attempts).to eq(1)
    end

    it "locks account after 3 consecutive failed login attempts", prosopite: false do
      3.times do
        post "/admin/login", params: {
          admin: { email: admin.email, password: "WrongPassword123!#" }
        }
      end

      admin.reload
      expect(admin.failed_attempts).to eq(3)
      expect(admin.locked_at).to be_present
      expect(admin.unlock_token).to be_present
    end
  end

  describe "Sidekiq Web UI SSO Protection (/admin/sidekiq)" do
    it "redirects unauthenticated visitors to admin sign-in" do
      get "/admin/sidekiq"
      expect(response).to redirect_to("/admin/login")
    end

    it "allows authenticated admins to view the Sidekiq Web UI" do
      post "/admin/login", params: {
        admin: { email: admin.email, password: "AdminSecret123!#" }
      }
      get "/admin/sidekiq"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /admin/logout" do
    it "logs out admin and revokes session access" do
      post "/admin/login", params: {
        admin: { email: admin.email, password: "AdminSecret123!#" }
      }
      delete "/admin/logout"
      expect(response).to redirect_to("/admin")
      follow_redirect!
      expect(response).to redirect_to("/admin/login")

      get "/admin"
      expect(response).to redirect_to("/admin/login")
    end
  end
end
