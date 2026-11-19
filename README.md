# Just Drink

A simple water tracker for iPhone and iPad. Tap the big glass each time you finish a
drink and watch it fill toward your daily goal.

## Features

- **One-tap logging.** The glass on the main screen records a drink from the selected
  container, with a haptic tap and protection against accidental double taps.
- **Water that moves.** The water level shows progress toward the goal. Tilt the phone
  and the water sloshes: it stays level with the ground, lags a quick tilt, overshoots
  and settles. It stays still when Reduce Motion is on.
- **Your own containers.** Save cups and bottles with a name, a size in oz, ml or L, and
  an optional photo, then swipe the cards to pick one.
- **Daily goal.** Optional. Each past day is judged against the goal that applied on that
  day, so changing the goal never rewrites history.
- **Drink log.** Records grouped by day with totals. Edit or delete any record.
- **Reminders.** Local notifications between a start and stop time, every 30 minutes,
  hour or two hours.
- **iCloud sync.** Everything syncs across your devices.
- **Locale-aware units.** Totals show in ounces or liters to match the device's region.

## Built with

- SwiftUI
- SwiftData, synced through CloudKit
- Core Motion for the tilt, driving a damped spring (`Views/TiltSpring.swift`,
  `Views/WaterTilt.swift`)
- UserNotifications for reminders

## Build

Open `JustDrink.xcodeproj` in Xcode 26 or later and run the `JustDrink` scheme on a
device or simulator running iOS 18 or later. To run on your own device, set your
development team and an iCloud container you own under Signing & Capabilities.

`IMPLEMENTATION_NOTES.md` describes each screen in detail, and `docs/TESTFLIGHT.md`
covers TestFlight builds.
