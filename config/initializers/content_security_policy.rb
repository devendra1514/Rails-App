# frozen_string_literal: true

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https
  end

  # Generate unique cryptographic nonces for permitted importmap and inline scripts.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s.presence || SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
