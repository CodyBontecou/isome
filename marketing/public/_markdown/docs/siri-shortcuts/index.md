§ Docs · Guide 9 of 11

# Siri & Shortcuts for iPhone location tracking

Build shortcuts for recording, reading your journal, renaming stops, and exporting files. Choose the dates and data you need, then check the result before adding an automation.

Platform

iOS 17+

Updated

October 26, 2026

Reading

5 min

Back to

[All docs](https://whereday.com/docs/)

## Find Whereday actions in Shortcuts

Open Apple’s Shortcuts app, create a shortcut, and search for Whereday when adding an action. The verified Whereday 1.7.16 release defines twelve actions. Nine have built-in Siri phrases; the three additional read actions can be added to a custom shortcut. Use the action names below when an older recipe shows different labels.

Set up location permission in Whereday before using Start Tracking. These actions are designed to run without opening Whereday, but iOS can still require interaction or permission. Test a shortcut manually before relying on an automation.

## Recording and today’s stats

Recording controls and snapshot values
| Action | What it does | Built-in Siri phrase example
| Start Tracking | Starts recording with the app’s location permission. | “Start Whereday”
| Stop Tracking | Stops recording. If Whereday is not running, closes the saved active session. | “Stop tracking with Whereday”
| Rename Current Outing | Names the active outing. Requires a nonempty Name and an active outing. | “Name my Whereday outing”
| Today’s Distance | Returns today’s distance from the latest shared app snapshot. | “How far have I gone with Whereday”
| Today’s Tracking Duration | Returns elapsed time for the current active recording, or zero when stopped. It is not a sum of every session today. | “Whereday tracking duration”
| Today’s Visits | Returns today’s visit count from the latest shared app snapshot. | “How many visits today in Whereday”

## Read and rename saved records

Journal actions for a custom shortcut
| Action | Inputs and result | Siri setup
| Get Current Outing Name | Returns the active outing’s name, or its start date if unnamed. Reports an error if there is no active outing. | Add to a custom shortcut.
| Get Visits | Optional Start Date and End Date. Returns visits whose arrival falls in the range. | Add to a custom shortcut.
| Get Movements | Optional Start Date and End Date. Returns recorded outings whose start falls in the range; “Movement” is the action’s label for an outing. | Add to a custom shortcut.
| Rename Visit | A saved Visit and a nonempty Name. Returns the renamed visit. | “Rename a visit in Whereday”
| Rename Movement | A saved Movement and a nonempty Name. Returns the renamed outing. | “Rename a movement in Whereday”

For a rename workflow, get the visits or movements, choose the intended result, and pass it to the matching rename action. Check the date and item before running: renaming changes the saved journal. These actions do not create missing GPS points or visits.

## Export a chosen date range

Export Data is the single configurable export action in this release. It returns a file for the next Shortcuts action. Its built-in Siri phrases include “Export Whereday data” and “Export data from Whereday”.

Export Data parameters
| Parameter | Choices or default
| Start Date | Defaults to the start of today in the device’s calendar.
| End Date | Defaults to the time the action runs.
| Data Kind | Visits, Points, Outings, or All Data. Defaults to All Data.
| Format | JSON, CSV, Markdown, GeoJSON, GPX, KML, OwnTracks, or Overland. Defaults to JSON.

For yesterday or any past period, set both dates. Leaving Start Date empty while setting yesterday’s End Date creates an inverted range and returns an error. An end before the start is invalid. Export formats organize records differently; consult the [export reference](https://whereday.com/docs/export-import/) before choosing a file for another app.

## Recipe: save today’s visits as Markdown

- Create a shortcut in Apple’s Shortcuts app and add Whereday’s Export Data action.
- Set Data Kind to Visits and Format to Markdown. Leave both date parameters empty for today up to the run time.
- Add Apple’s Save File action after Export Data, using the returned file as its input. For the first run, choose a test folder you control.
- Run the shortcut manually. Confirm the saved file has the expected date heading and visits. A successful action is not proof that you recorded every stop.
- For a desktop vault, follow the [Obsidian file handoff](https://whereday.com/blog/iphone-location-journal-obsidian/). Keep personal writing separate from generated exports.

This recipe follows the released action’s parameters and Apple’s documented file actions. The export logic is covered by native tests; the complete Shortcuts editor, Save File destination, and unattended delivery have not been newly verified here. Apple explains [creating a custom shortcut](https://support.apple.com/guide/shortcuts/create-a-custom-shortcut-apd84c576f8c/ios) and [passing files to sharing actions](https://support.apple.com/guide/shortcuts/share-actions-apdaf74d75a5/ios).

## Check a shortcut before scheduling it

- If an old shortcut shows Export Today’s Data, Export Today’s Outings, or Export Yesterday’s Data, rebuild that step with Export Data and set its dates, data kind, and format explicitly.
- If a result is empty, check the date range and whether the app actually recorded the intended data. Read actions match visit arrival or outing start; a record overlapping the period can start outside it.
- If a file was returned but is missing from Files, check the following Save File action and destination. Export Data does not itself configure a recurring vault sync.
- For Whereday’s own folder scheduler, use the separate [automatic export reference](https://whereday.com/docs/automatic-exports/). For missing journal entries, use the [recording checklist](https://whereday.com/blog/missing-location-history-iphone/).

Reviewed October 26, 2026 against the released Whereday 1.7.16 action definitions. Siri wording and the Shortcuts editor can vary by language and iOS version.

[← PreviousWebhooks & self-hosting](https://whereday.com/docs/webhooks/) [Next →Record Apple Watch GPS routes without your iPhone](https://whereday.com/docs/apple-watch/)

Source: https://whereday.com/docs/siri-shortcuts/
