# TecHub Components

Part of what I learned with TechDeck is that I should build out each component of the application as a stand alone thing, with a known input and output.

## GitHub

We need to be able to get a user's GitHub profile data.

```plaintext
https://github.com/settings/apps/new

GitHub App name: TecHub-life
GitHub App description:

AI-powered collectible trading cards for GitHub developer profiles

Part discovery engine, part vibe board, part trading card game for builders.

Created by Jared Hooker ([@GameDevJared89](https://x.com/GameDevJared89)) and Dean Lofts ([@loftwah](https://x.com/loftwah)).

Callback URLs:
https://techub.life/auth/github/callback
http://localhost:3000/auth/github/callback

Setup URL: https://techub.life/install/complete
Redirect on update: false (Redirect users to the 'Setup URL' after installations are updated)

Where can this GitHub App be installed?: Any account

https://github.com/settings/apps/techub-life

Background color: #051c5f
```