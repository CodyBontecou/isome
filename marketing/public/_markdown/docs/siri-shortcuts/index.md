§ Docs · Guide 9 of 11

# Siri & Shortcuts

iso.me exposes nine App Intents that work in the Shortcuts app, from Siri, and from automations like the Action Button — including exports handed straight to other apps.

Platform

iOS 17+

Updated

August 22, 2026

Reading

3 min

Back to

[All docs](https://isome.isolated.tech/docs/)

## Nine actions

Every action runs without opening the app. Find them in the Shortcuts app under iso.me, or just talk to Siri.

| Action | What it does | Siri phrase example
| Start Tracking | Begins a recording session. | “Start iso.me”
| Stop Tracking | Ends the session — even if the app isn't running. | “Stop tracking with iso.me”
| Rename Current Outing | Sets the active outing's name (parameter: name). | “Name my iso.me outing”
| Today's Distance | Returns how far you've moved today. | “How far have I gone with iso.me?”
| Today's Tracking Duration | Returns how long the session has run. | “iso.me tracking duration”
| Today's Visits | Returns today's visit count. | “How many visits today in iso.me?”
| Export Today's Data | Produces a file of today's visits and route (parameter: format, default JSON). | “Export today's data from iso.me”
| Export Today's Outings | Same, for outings. | “Export today's iso.me outings”
| Export Yesterday's Data | Yesterday's visits and route as a file. | “Export yesterday's iso.me tracks”

## Automation ideas

- Bind Start Tracking to the Action Button for one-press recording.
- An automation that runs Export Today's Data every evening and hands the file to another shortcut — your own export pipeline.
- Ask Siri for Today's Visits or Distance as a daily digest.
- Rename an outing mid-hike: “Name my iso.me outing Ridge Trail.”

Export actions produce a file in your chosen format that Shortcuts can save, message, or pass to other apps.

[← PreviousWebhooks & self-hosting](https://isome.isolated.tech/docs/webhooks/) [Next →Record Apple Watch GPS routes without your iPhone](https://isome.isolated.tech/docs/apple-watch/)

Source: https://isome.isolated.tech/docs/siri-shortcuts/
