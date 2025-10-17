module Ops
  class OwnershipsController < BaseController
    before_action :load_ownership, only: [ :promote, :demote, :destroy ]

    def index
      @ownerships = ProfileOwnership.includes(:user, :profile).order("profiles.login ASC, users.login ASC").references(:user, :profile)
    end

    def promote
      ActiveRecord::Base.transaction do
        @ownership.update!(is_owner: true)
        impacted_ids = ProfileOwnership.where(profile_id: @ownership.profile_id).where.not(id: @ownership.id).pluck(:user_id)
        ProfileOwnership.where(profile_id: @ownership.profile_id).where.not(id: @ownership.id).delete_all

        # Best-effort notifications
        Notifications::RecordEventService.call(user: @ownership.user, event: :ownership_claimed, subject: @ownership.profile)
        impacted_ids.uniq.each do |uid|
          if (u = User.find_by(id: uid))
            Notifications::RecordEventService.call(user: u, event: :ownership_link_removed, subject: @ownership.profile)
          end
        end
      end
      redirect_to ops_ownerships_path, notice: "Promoted to owner"
    rescue StandardError => e
      redirect_to ops_ownerships_path, alert: e.message
    end

    def demote
      @ownership.update(is_owner: false)
      redirect_to ops_ownerships_path, notice: "Demoted from owner"
    rescue StandardError => e
      redirect_to ops_ownerships_path, alert: e.message
    end

    def destroy
      @ownership.destroy!
      redirect_to ops_ownerships_path, notice: "Ownership removed"
    rescue StandardError => e
      redirect_to ops_ownerships_path, alert: e.message
    end

    private

    def load_ownership
      @ownership = ProfileOwnership.find_by(id: params[:id])
      redirect_to ops_ownerships_path, alert: "Ownership not found" unless @ownership
    end
  end
end
