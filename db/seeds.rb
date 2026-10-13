# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
if Rails.env.development?
  Admin.find_or_create_by!(email: "admin@example.com") do |admin|
    admin.password = "AdminSecret123!#"
    admin.password_confirmation = "AdminSecret123!#"
  end
  puts "Development Admin created: admin@example.com / AdminSecret123!#"
elsif Rails.env.production?
  if ENV["INITIAL_ADMIN_EMAIL"].present? && ENV["INITIAL_ADMIN_PASSWORD"].present?
    Admin.find_or_create_by!(email: ENV["INITIAL_ADMIN_EMAIL"]) do |admin|
      admin.password = ENV["INITIAL_ADMIN_PASSWORD"]
      admin.password_confirmation = ENV["INITIAL_ADMIN_PASSWORD"]
    end
  end
end
