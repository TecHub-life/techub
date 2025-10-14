module Profiles
  module AiOverrides
    module_function

    # Return a symbol-keyed hash of overrides for a given profile/login
    # Keys may include: :attack, :defense, :speed, :playing_card, :spirit_animal, :archetype
    def for(profile_or_login)
      login = profile_or_login.respond_to?(:login) ? profile_or_login.login.to_s.downcase : profile_or_login.to_s.downcase

      case login
      when "loftwah"
        { playing_card: "Ace of ♣", spirit_animal: "Koala", archetype: "The Hero" }
      else
        {}
      end
    end
  end
end
