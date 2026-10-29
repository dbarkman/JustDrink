# JustDrink Implementation Notes

## ✅ Completed Features

### Data Models (SwiftData)
- **Container**: Stores water containers with name, capacity, unit, optional photo, and color index
- **DrinkRecord**: Records drink history with timestamp, container details (snapshot at time of recording)
- **DailyGoal**: Optional daily hydration goal
- **DailyGoalHistory**: The goal in milliliters from each change (0 = removed), so past days are judged against the goal that applied then
- **ReminderSettings**: Notification preferences and schedule
- **AppState**: Tracks last drink time and selected container

All models are stored with SwiftData and sync through iCloud (CloudKit).

### Main Screen
- ✅ Today's date and total at the top, with the percentage of the daily goal (or a "Set Goal" button)
- ✅ Large round glass button to record a drink; its water level shows progress toward the goal, with a gentle wave (still when Reduce Motion is on)
- ✅ Tilting the phone sloshes the water: it stays level with the ground, lags a quick tilt, overshoots and settles, with bigger waves while it moves (a damped spring on Core Motion gravity; off with Reduce Motion, paused while a sheet covers the screen)
- ✅ Haptic tap when a drink is recorded
- ✅ 1-minute duplicate tap protection with confirmation alert
- ✅ Horizontal scrolling container cards (picture, name, size) with the selected one centered and checked
- ✅ Floating bottom bar for Drink Log, Containers, Daily Goal and Reminders
- ✅ Disabled glass and an "Add a container" prompt when no containers exist
- ✅ Remembers last selected container; when containers are added or deleted the selection stays on it, or moves to the card now in its place
- ✅ Total updates as soon as a drink is recorded, edited or deleted, at midnight, and when the app returns to the foreground

### Container Setup Screen
- ✅ List view of all containers with photos/icons
- ✅ Tap to edit, swipe to delete
- ✅ Add new containers with required capacity field
- ✅ Unit picker: oz, ml, L
- ✅ Optional photo (camera or library), stored as a JPEG at most 1024 px on its longest side; re-encoded only when it changes
- ✅ Rainbow color coding for containers using default SF Symbol (waterbottle.fill)
- ✅ Default 500ml Costco water bottle created on first launch; a launch clean-up removes duplicate copies of that default (from iCloud sync) and never touches containers the user made

### Drink Log Screen
- ✅ Records grouped by day with totals
- ✅ Shows "Today", "Yesterday", or formatted date
- ✅ Displays goal comparison for each day (encouraging messages), against the goal in effect that day
- ✅ Tap record to edit (name, capacity, unit, timestamp)
- ✅ Swipe to delete records
- ✅ Historical records never change when containers are modified/deleted

### Daily Goal Screen
- ✅ Half-sheet presentation
- ✅ Simple form: amount + unit picker
- ✅ Defaults to user's locale (oz for US, L for metric)
- ✅ Optional - can be removed
- ✅ Used throughout app for progress tracking

### Reminders Config Screen
- ✅ Enable/disable switch
- ✅ Start time, stop time, and frequency pickers; start and stop default to 8:00 AM and 10:00 PM
- ✅ Pickers disabled when switch is off
- ✅ Requests notification permissions on first enable
- ✅ Alert with Settings button if permissions are denied
- ✅ Frequency options: 30 min, 1 hour, 2 hours
- ✅ Nothing is scheduled or cancelled until Save; Close leaves the saved schedule as it was
- ✅ A footer sums up the schedule in one sentence

### Notifications
- ✅ Titled "Just Drink", with 5 rotating fun messages with water emojis (💧💦🚰🧊🌊) as the body
- ✅ Daily recurring schedule from the start time through the stop time; a stop time earlier than the start runs past midnight into the next morning (`NotificationManager.reminderSlots`)
- ✅ Properly canceled when disabled
- ✅ When the app opens or returns to the foreground: scheduled from the saved settings if they're on and nothing is pending (a reinstall, a new phone, settings synced from iCloud), cancelled if they're off. An existing schedule is left alone, since its triggers follow the local clock when the time zone changes; `reminderScheduleVersion` forces one rebuild after an update that changes how slots are made

### Locale Support
- ✅ Stores containers in user-entered units
- ✅ Displays totals in user's locale (oz for US, L with decimals for metric)
- ✅ No rounding - full precision maintained

## 📋 TODO for David

### Required: Add Default Water Bottle Image
1. Add an image named **"defaultBottle"** to the Assets catalog
2. This will be used for the default 500ml Costco water bottle
3. If not added, the default container will use the blue waterbottle.fill SF Symbol

### Steps to Add Image:
1. Open `JustDrink.xcodeproj` in Xcode
2. Navigate to `Assets.xcassets`
3. Right-click → New Image Set
4. Name it `defaultBottle`
5. Drag your water bottle photo into the 1x slot

## 🏗️ Architecture

### Design Patterns
- **Singleton**: `DataManager` and `NotificationManager` (per your preference)
- **SwiftData**: Persistence, synced through CloudKit
- **No Combine**: Pure SwiftUI state management

### Key Files
- `Models/` - All SwiftData models
- `Views/` - All SwiftUI views (one per screen)
- `Views/Theme.swift` - Colors (light and dark), rounded type, navigation title style
- `Views/Components.swift` - Shared pieces: the water glass, container icons, progress bar, button style
- `Views/TiltSpring.swift` - The slosh physics: level angle from gravity and the damped spring (plain math, no frameworks)
- `Views/WaterTilt.swift` - Feeds Core Motion gravity into the spring while the glass is on screen
- `DataManager.swift` - Centralized data operations
- `NotificationManager.swift` - Notification scheduling
- `JustDrinkApp.swift` - App entry point with the CloudKit-backed ModelContainer

## 🎨 UI/UX Highlights
- Clean, simple interface focused on one primary action: tap the glass
- Watery blue palette with SF Rounded type, in light and dark mode
- App icon of a round glass of water, with dark and tinted versions
- Every screen one tap away in the bottom bar
- Encouraging messaging (no shame-based motivation)
- Smart defaults (500ml bottle ready to go)
- Locale-aware unit display
- Color-coded default containers for easy identification
- Dynamic Type throughout; VoiceOver labels on the glass and container cards

## 🧪 Testing the App

1. Build and run on iOS 18.0+ device or simulator
2. Default container should appear immediately
3. Tap the glass to record a drink
4. Try tapping again within 1 minute to see duplicate alert
5. Add containers with Containers in the bottom bar
6. Set a daily goal to see the glass fill
7. Check drink log to see grouped records
8. Enable reminders and approve notifications

## 📱 Permissions Required
- **Photo Library**: To add custom container photos
- **Camera**: To take photos of containers
- **Notifications**: For drink reminders

All permissions are handled with appropriate Info.plist descriptions.

## ☁️ Sync
The SwiftData store syncs through the iCloud container `iCloud.RedMesaStudios.JustDrink` (`cloudKitDatabase: .automatic`). Because of the iCloud entitlement, signing needs Xcode signed in to the developer account; the general team profile can't sign it.

## 🚀 Ready to Ship!
The app is complete and ready for testing. Once you add the default water bottle image, you'll have a fully functional MVP ready for the App Store! 🎉


