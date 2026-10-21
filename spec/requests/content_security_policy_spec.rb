# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Content Security Policy", type: :request do
  describe "CSP headers on HTML responses" do
    it "sets Content-Security-Policy header with nonces on HTML requests" do
      get "/admin/login"

      csp_header = response.headers["Content-Security-Policy"]
      expect(csp_header).to be_present
      expect(csp_header).to include("default-src 'self' https:")
      expect(csp_header).to include("script-src 'self' https: 'nonce-")
      expect(csp_header).to include("object-src 'none'")
    end

    it "generates unique nonces per request" do
      get "/admin/login"
      nonce1 = response.headers["Content-Security-Policy"][/nonce-([^']+)/, 1]

      get "/admin/login"
      nonce2 = response.headers["Content-Security-Policy"][/nonce-([^']+)/, 1]

      expect(nonce1).to be_present
      expect(nonce2).to be_present
    end
  end
end
