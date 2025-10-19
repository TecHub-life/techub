module Api
  module V1
    class LeaderboardsController < ApplicationController
      def podium
        kind = params[:kind].presence || "followers_gain_30d"
        window = params[:window].presence || "30d"
        lb = Leaderboard.where(kind: kind, window: window).order(as_of: :desc).first
        if lb.nil?
          result = Leaderboards::ComputeService.call(kind: kind, window: window, as_of: Date.today)
          lb = result.success? ? result.value : nil
        end
        if lb
          render json: { kind: lb.kind, window: lb.window, as_of: lb.as_of, podium: Array(lb.entries).first(3) }
        else
          render json: { error: "leaderboard unavailable" }, status: :not_found
        end
      end
      def index
        kind = params[:kind].presence || "followers_total"
        window = params[:window].presence || "30d"
        as_of = (params[:as_of].presence && Date.parse(params[:as_of])) rescue Date.today

        lb = Leaderboard.where(kind: kind, window: window).order(as_of: :desc).first
        if lb.nil? || (lb.as_of != as_of && params[:as_of].present?)
          result = Leaderboards::ComputeService.call(kind: kind, window: window, as_of: as_of)
          lb = result.success? ? result.value : nil
        end

        if lb
          render json: { kind: lb.kind, window: lb.window, as_of: lb.as_of, entries: lb.top(100) }
        else
          render json: { error: "leaderboard unavailable" }, status: :not_found
        end
      end
    end
  end
end
