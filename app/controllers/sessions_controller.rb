class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
    redirect_to favorites_path if authenticated?
  end

  def create
    result = UrlFavorites::UseCases::Authentication::CreateSession.call(
      email_address: session_params[:email_address],
      password: session_params[:password],
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )

    if result.ok?
      start_new_session(result.value[:session])
      redirect_to after_authentication_url, notice: "로그인되었습니다."
    else
      flash.now[:alert] = "이메일 또는 비밀번호가 올바르지 않습니다."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_current_session
    redirect_to new_session_path, notice: "로그아웃되었습니다."
  end

  private

  def session_params
    params.require(:session).permit(:email_address, :password)
  end
end
