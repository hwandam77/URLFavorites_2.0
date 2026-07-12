module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_session
    before_action :require_authentication
    helper_method :authenticated?, :current_user
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def authenticated?
    Current.session.present?
  end

  def current_user
    Current.user
  end

  def require_authentication
    authenticated? || request_authentication
  end

  def resume_session
    return true if Current.session.present?

    result = UrlFavorites::UseCases::Authentication::ResumeSession.call(
      token: cookies.signed[:session_token]
    )

    return false unless result.ok?

    Current.session = result.value[:session]
  end

  def request_authentication
    store_location_after_authentication
    redirect_to new_session_path, alert: "로그인이 필요합니다."
  end

  def start_new_session(session_record)
    Current.session = session_record
    cookies.signed.permanent[:session_token] = {
      value: session_record.token,
      httponly: true,
      same_site: :lax
    }
  end

  def terminate_current_session
    UrlFavorites::UseCases::Authentication::DestroySession.call(session: Current.session)
    cookies.delete(:session_token)
    Current.session = nil
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || favorites_path
  end

  def store_location_after_authentication
    return unless request.get?
    return if request.xhr?

    session[:return_to_after_authenticating] = request.fullpath
  end
end
