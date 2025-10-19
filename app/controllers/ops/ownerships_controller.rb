module Ops
  class OwnershipsController < BaseController
    before_action :load_ownership, only: [ :promote, :transfer, :destroy ]

    def index
      @profiles = Profile.order("login ASC")
      @users = User.order("login ASC").limit(1000)
      @profiles_with_links = Profile.includes(profile_ownerships: :user).order("profiles.login ASC")
    end

    def promote
      ActiveRecord::Base.transaction do
        impacted_ids = ProfileOwnership.where(profile_id: @ownership.profile_id).where.not(id: @ownership.id).pluck(:user_id)
        # Remove all other links first to satisfy single-owner validation
        ProfileOwnership.where(profile_id: @ownership.profile_id).where.not(id: @ownership.id).delete_all
        @ownership.update!(is_owner: true)

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

    # Transfer ownership of a profile to another user login.
    # Params: target_login (GitHub login)
    def transfer
      target_login = params[:target_login].to_s.downcase
      return redirect_to ops_ownerships_path, alert: "Target login required" if target_login.blank?

      target_user = User.find_by(login: target_login)
      return redirect_to ops_ownerships_path, alert: "User not found" unless target_user

      ActiveRecord::Base.transaction do
        # Remove all links except any existing link for the target user (if present)
        ProfileOwnership.where(profile_id: @ownership.profile_id).where.not(user_id: target_user.id).delete_all

        # Promote or create link for target user to this profile as the single owner
        link = ProfileOwnership.find_or_initialize_by(user_id: target_user.id, profile_id: @ownership.profile_id)
        link.is_owner = true
        link.save!
      end

      redirect_to ops_ownerships_path(profile: @ownership.profile.login), notice: "Transferred ownership to @#{target_login}"
    rescue StandardError => e
      redirect_to ops_ownerships_path, alert: e.message
    end

    # Set owner for an orphaned profile (no owner_link present)
    # Params: profile_login, target_login
    def set_owner
      plogin = params[:profile_login].to_s.downcase
      tlogin = params[:target_login].to_s.downcase
      return redirect_to ops_ownerships_path, alert: "Profile and target required" if plogin.blank? || tlogin.blank?

      profile = Profile.for_login(plogin).first || Profile.find_by(login: plogin)
      user = User.find_by(login: tlogin)
      return redirect_to ops_ownerships_path, alert: "Profile not found" unless profile
      return redirect_to ops_ownerships_path, alert: "User not found" unless user

      # Guard: only allowed for orphaned profiles (no current owner)
      if ProfileOwnership.where(profile_id: profile.id, is_owner: true).exists?
        return redirect_to ops_ownerships_path, alert: "Profile already has an owner. Use Transfer."
      end

      ActiveRecord::Base.transaction do
        link = ProfileOwnership.find_or_initialize_by(user_id: user.id, profile_id: profile.id)
        link.is_owner = true
        link.save!
        ProfileOwnership.where(profile_id: profile.id).where.not(id: link.id).delete_all
      end
      redirect_to ops_ownerships_path, notice: "Set @#{tlogin} as owner for @#{plogin}"
    rescue StandardError => e
      redirect_to ops_ownerships_path, alert: e.message
    end

    # Transfer ownership by specifying profile and target user logins directly
    # Params: profile_login, target_login
    def transfer_by_profile
      plogin = params[:profile_login].to_s.downcase
      tlogin = params[:target_login].to_s.downcase
      return redirect_to ops_ownerships_path, alert: "Profile and target required" if plogin.blank? || tlogin.blank?

      profile = Profile.for_login(plogin).first || Profile.find_by(login: plogin)
      user = User.find_by(login: tlogin)
      return redirect_to ops_ownerships_path, alert: "Profile not found" unless profile
      return redirect_to ops_ownerships_path, alert: "User not found" unless user

      ActiveRecord::Base.transaction do
        # Remove all links except any existing link for the target user (if present)
        ProfileOwnership.where(profile_id: profile.id).where.not(user_id: user.id).delete_all

        link = ProfileOwnership.find_or_initialize_by(user_id: user.id, profile_id: profile.id)
        link.is_owner = true
        link.save!
      end

      redirect_to ops_ownerships_path(profile: profile.login), notice: "Transferred ownership to @#{tlogin}"
    rescue StandardError => e
      redirect_to ops_ownerships_path, alert: e.message
    end

    # Link is no longer supported; profiles have exactly one owner.

    def destroy
      # Prevent deleting the current owner link; use transfer instead
      if @ownership.is_owner || (@ownership.user&.login.to_s.casecmp(@ownership.profile&.login.to_s).zero?)
        redirect_to ops_ownerships_path(profile: @ownership.profile.login), alert: "Cannot remove owner link. Use transfer."
        return
      end

      @ownership.destroy!
      redirect_to ops_ownerships_path, notice: "Ownership link removed"
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
