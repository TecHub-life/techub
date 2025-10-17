module Ops
  class UsersController < BaseController
    def search
      q = params[:q].to_s.strip.downcase
      return render json: [] if q.blank?

      users = User.where("LOWER(login) LIKE ?", "%#{q}%").order("login ASC").limit(20)
      render json: users.map { |u| { login: u.login } }
    end
  end
end
