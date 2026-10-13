# frozen_string_literal: true

ActiveAdmin.register Admin do
  permit_params :email, :password, :password_confirmation

  index do
    selectable_column
    id_column
    column :email
    column :current_sign_in_at
    column :sign_in_count
    column :locked_at
    column :created_at
    actions
  end

  filter :email
  filter :current_sign_in_at
  filter :sign_in_count
  filter :created_at

  form do |f|
    f.inputs do
      f.input :email
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end

  controller do
    def update
      if params[:admin][:password].blank? && params[:admin][:password_confirmation].blank?
        params[:admin].delete("password")
        params[:admin].delete("password_confirmation")
      end
      super
    end
  end
end
