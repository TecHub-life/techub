# frozen_string_literal: true

require "json"

def availability
  {
    ai_studio: Gemini::Configuration.api_key.to_s.strip.length > 0,
    vertex: Gemini::Configuration.project_id.to_s.strip.length > 0
  }
end

def sync_profile(login)
  res = Profiles::SyncFromGithub.call(login: login)
  raise(res.error || StandardError.new("sync failed")) if res.failure?
  res.value
end

def synthesize_traits(profile, provider)
  res = Profiles::SynthesizeAiProfileService.call(profile: profile, provider: provider)
  if res.failure?
    { ok: false, error: res.error.message, metadata: res.metadata }
  else
    card = res.value
    {
      ok: true,
      attack: card.attack,
      defense: card.defense,
      speed: card.speed,
      tags: Array(card.tags_array).first(6),
      model: card.ai_model,
      generated_at: card.generated_at
    }
  end
end

def synthesize_story(profile, provider)
  res = Profiles::StoryFromProfile.call(login: profile.login, profile: profile, provider: provider)
  if res.failure?
    { ok: false, error: res.error.message, metadata: res.metadata }
  else
    {
      ok: true,
      finish_reason: res.metadata[:finish_reason],
      excerpt: res.value.to_s.split("\n").first.to_s[0, 160]
    }
  end
end

login = (ENV["LOGIN"] || "loftwah").to_s.downcase
providers = []
avail = availability
providers << "ai_studio" if avail[:ai_studio]
providers << "vertex" if avail[:vertex]

output = { login: login, available_providers: providers }

begin
  profile = sync_profile(login)
  output[:profile_id] = profile.id
  output[:providers] = {}

  providers.each do |provider|
    traits = synthesize_traits(profile, provider)
    story = synthesize_story(profile, provider)
    output[:providers][provider] = { traits: traits, story: story }
  end
rescue => e
  output[:error] = e.message
end

puts JSON.pretty_generate(output)
