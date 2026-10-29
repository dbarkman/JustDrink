# TestFlight

## Beta App Description

Just Drink is a simple water tracker. Tap the big glass each time you finish a drink and watch it fill up toward your daily goal. You can save your own cups and bottles (with a photo if you like), look back at past days in the Drink Log, and get friendly reminders to drink during the day. Your drinks are saved to your own iCloud account.

## What to Test (build 2026102901)

- Tap the glass to log a drink, and check that the total and the water level go up.
- Tilt your phone and watch the water slosh in the glass.
- Add your own cup or bottle under Containers, then swipe the cards to pick it.
- Set a daily goal and see if the percentage and the glass look right through the day.
- Turn on Reminders, pick your hours, and tell us if a reminder ever arrives outside them.
- Edit or delete a drink in the Drink Log and make sure the totals update.

## Build notes

- The App Store Connect record "Just Drink" uses the bundle ID `com.redmesastudios.JustDrink`. The `main` branch builds `com.redmesastudios.JustDrink.dev`; TestFlight builds are archived from the local `testflight` branch, which switches the app target to `com.redmesastudios.JustDrink` and keeps the iCloud container `iCloud.RedMesaStudios.JustDrink`.
- TestFlight and App Store builds use the CloudKit **Production** environment. Deploy the schema to Production in the CloudKit Console before uploading a build that adds or changes a model.
- The build number is `CURRENT_PROJECT_VERSION` in the date format `YYYYMMDDNN`; `ITSAppUsesNonExemptEncryption` is `NO` (standard HTTPS and iCloud only).
- `JustDrink/PrivacyInfo.xcprivacy` declares no tracking, no collected data, and one required-reason API: UserDefaults (`CA92.1`), used for the notification message rotation and the reminder schedule version.
