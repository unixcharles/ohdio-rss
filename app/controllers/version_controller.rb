# Plain JSON endpoint, kept off ApplicationController so allow_browser never blocks curl or monitors.
class VersionController < ActionController::Base
  def show
    render json: AppVersion.to_h
  end
end
