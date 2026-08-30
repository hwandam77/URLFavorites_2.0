# frozen_string_literal: true

class PasswordsController < ApplicationController
  def edit
  end

  def update
    result = UrlFavorites::UseCases::Authentication::UpdatePassword.call(
      user: Current.user,
      current_password: password_params[:current_password],
      password: password_params[:password],
      password_confirmation: password_params[:password_confirmation],
      keep_session: Current.session
    )

    if result.ok?
      redirect_to edit_password_path, notice: "비밀번호가 변경되었습니다."
    else
      flash.now[:alert] =
        if result.error == :wrong_current_password
          "현재 비밀번호가 올바르지 않습니다."
        else
          "새 비밀번호가 조건에 맞지 않습니다. (최소 6자)"
        end
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:password).permit(:current_password, :password, :password_confirmation)
  end
end
