# HabitQuest

A SwiftUI iOS app for tracking healthy habits, with a points/streak/badge
reward system and local push notifications to remind you to do each habit.

## What it does

- **Habits**: create habits with an icon, color, and a weekly target (e.g.
  "Exercise, 4x/week").
- **Today tab**: one tap to mark a habit done for the day; shows weekly
  progress as a ring and the current streak.
- **Rewards tab**: points (10 per completion + a 30-point bonus each week you
  hit a habit's target), levels (Seedling → Legend), and streak badges
  (2/4/8/12/26/52 consecutive weeks meeting a goal).
- **Reminders**: set one or more day+time slots per habit. The app schedules
  recurring **local notifications** (via `UNUserNotificationCenter`), so no
  server, Apple Developer Program, or internet connection is required — they
  fire straight from the device. Notifications include a "Mark Done" action
  button that logs the habit as complete without opening the app.

Everything is stored on-device with SwiftData — no account or backend.

## Project layout

```
HabitQuest/
  project.yml                  # XcodeGen spec (optional, see below)
  HabitQuest/
    HabitQuestApp.swift         # App entry point, SwiftData container
    ContentView.swift           # Tab bar (Today / Habits / Rewards)
    Models/
      Habit.swift               # SwiftData model + completion helpers
      HabitCompletion.swift     # SwiftData model (one row per completed day)
      ReminderSlot.swift        # Codable weekday+time struct
    Engine/
      PointsEngine.swift        # Pure functions: points, streaks, levels
    Notifications/
      NotificationManager.swift # Schedules/cancels local notifications
    Views/
      TodayView.swift
      HabitsListView.swift
      AddEditHabitView.swift
      HabitDetailView.swift
      RewardsView.swift
    Utilities/
      ColorExtensions.swift
    Assets.xcassets/            # Placeholder app icon + accent color
```

## Getting it running on your iPhone

You'll need a Mac with Xcode (free from the App Store) and a USB cable or
same-Wi-Fi connection to your iPhone. You do **not** need a paid Apple
Developer account to build and run on your own device — a free Apple ID
works, the app just needs re-installing every 7 days in that case.

### Option A — XcodeGen (recommended, generates the `.xcodeproj` for you)

1. On your Mac: `brew install xcodegen` (one-time).
2. `cd HabitQuest` (this folder) and run `xcodegen generate`.
3. Open the generated `HabitQuest.xcodeproj` in Xcode.
4. Select the `HabitQuest` target → **Signing & Capabilities** → choose your
   Apple ID as the Team (Xcode will offer to create one if needed).
5. Plug in your iPhone, select it as the run destination, and hit **Run**
   (▶). The first time, you'll need to trust the developer certificate on
   the phone: Settings → General → VPN & Device Management.
6. Open the app, add a habit, add a reminder — iOS will prompt for
   notification permission the first time you save one.

### Option B — Manual Xcode project

1. In Xcode: **File → New → Project → iOS → App**. Name it `HabitQuest`,
   interface **SwiftUI**, language **Swift**, and set the deployment target
   to iOS 17.
2. Delete the placeholder `ContentView.swift`/`Item.swift`/app file Xcode
   generates.
3. Drag the contents of this repo's `HabitQuest/HabitQuest/` folder into the
   Xcode project navigator (check "Copy items if needed" and make sure the
   `HabitQuest` target is checked).
4. Build and run as in steps 4–6 above.

## Notes on notifications

- These are **local** notifications scheduled on-device, not server-sent
  push — that's the right tool here since reminders are personal and don't
  need to come from a backend. If you later want notifications triggered by
  something server-side (e.g. a friend nudging you), that would need Apple
  Push Notification service (APNs) plus a server component — a much bigger
  lift than this app needs today.
- Notifications only fire once you've granted permission (prompted the
  first time you save a habit with a reminder) and only while the app has
  been installed/run at least once.
- Reminders repeat weekly on the chosen day/time (`UNCalendarNotificationTrigger`
  with `repeats: true`), so you only need to set them up once per habit.
