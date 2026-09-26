# HabitQuest

A SwiftUI iOS app for tracking healthy habits, with a points/streak/badge
reward system, local reminders, and a "Circle" feature so you can invite
friends and family to set their own goals, see each other's progress, and
message each other for encouragement.

## What it does

- **Habits**: create habits with an icon, color, and a weekly target (e.g.
  "Exercise, 4x/week"). Fully private by default.
- **Today tab**: one tap to mark a habit done for the day; shows weekly
  progress as a ring and the current streak.
- **Rewards tab**: points (10 per completion + a 30-point bonus each week you
  hit a habit's target), levels (Seedling → Legend), and streak badges
  (2/4/8/12/26/52 consecutive weeks meeting a goal).
- **Reminders**: set one or more day+time slots per habit. The app schedules
  recurring **local notifications** (via `UNUserNotificationCenter`), so no
  server or internet connection is required for these — they fire straight
  from the device. Notifications include a "Mark Done" action button that
  logs the habit as complete without opening the app.
- **Circle tab**: create a "Circle" (a shared group) and invite friends or
  family via the native iOS share sheet (Messages, Mail, copy link — powered
  by CloudKit sharing, tied to everyone's existing iCloud accounts, no new
  sign-up). Each person keeps their own private habit list, but can flip a
  "Share progress with your Circle" toggle per habit to publish just its
  weekly progress and streak (not the day-by-day log) to the group. Everyone
  in the Circle can see everyone else's shared goals, send a one-tap "Cheer,"
  or use the group chat to motivate each other.

Personal habit data lives on-device via SwiftData. Circle data (shared
goals + chat) lives in CloudKit, scoped to the people you've invited.

## Project layout

```
HabitQuest/
  project.yml                  # XcodeGen spec (optional, see below)
  HabitQuest/
    HabitQuestApp.swift         # App entry point, SwiftData + CloudKit wiring
    AppDelegate.swift            # CKShare acceptance, remote notification handling
    ContentView.swift           # Tab bar (Today / Habits / Circle / Rewards)
    Models/
      Habit.swift               # SwiftData model + completion helpers
      HabitCompletion.swift     # SwiftData model (one row per completed day)
      ReminderSlot.swift        # Codable weekday+time struct
    Engine/
      PointsEngine.swift        # Pure functions: points, streaks, levels
    Notifications/
      NotificationManager.swift # Schedules/cancels local + circle notifications
    CloudKit/
      CloudKitManager.swift     # Circle creation/join, sync, messaging
      CircleModels.swift        # Codable structs for members/goals/messages
    Views/
      TodayView.swift
      HabitsListView.swift
      AddEditHabitView.swift
      HabitDetailView.swift
      RewardsView.swift
      CircleView.swift          # Members list + shared progress
      CircleChatView.swift      # Group chat
      CreateCircleView.swift
      JoinCircleNameView.swift
      CloudSharingView.swift    # Wraps UICloudSharingController (invite sheet)
    Utilities/
      ColorExtensions.swift
    Assets.xcassets/            # Placeholder app icon + accent color
```

## Getting it running on your iPhone

You'll need a Mac with Xcode (free from the App Store) and a USB cable or
same-Wi-Fi connection to your iPhone.

### Option A — XcodeGen (recommended, generates the `.xcodeproj` for you)

1. On your Mac: `brew install xcodegen` (one-time).
2. `cd HabitQuest` (this folder) and run `xcodegen generate`.
3. Open the generated `HabitQuest.xcodeproj` in Xcode.
4. Select the `HabitQuest` target → **Signing & Capabilities** → choose your
   Apple ID as the Team. This also needs an **iCloud container** — Xcode
   will offer to create `iCloud.com.andrewkonstand.habitquest` automatically
   the first time you build; if it doesn't, add it manually under the
   iCloud capability (CloudKit checked).
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
4. Select the target → **Signing & Capabilities** → **+ Capability**, and add:
   - **iCloud** → check **CloudKit**, and add/create a container (e.g.
     `iCloud.com.yourdomain.habitquest`).
   - **Push Notifications**.
   - **Background Modes** → check **Remote notifications**.
5. Build and run as in steps 4–6 above.

## Setting up your Circle (friends & family)

1. Open the **Circle** tab and tap **Create a Circle**. Give it a name and
   pick your own display name/color (this is what your friends and family
   will see — not your Apple ID).
2. Right after creating it, iOS's standard sharing sheet opens — send the
   invite link via Messages, Mail, or copy it. Anyone who taps the link and
   has the app installed (built the same way, from this same project) will
   be prompted to accept and join.
3. Each invitee picks their own display name/color the first time they open
   the Circle tab after accepting.
4. In **Habits → (a habit) → Edit**, flip on **"Share progress with your
   Circle"** for any habit you want the group to see. Everyone in the Circle
   then sees your weekly count and streak for that habit on their own Circle
   tab, and can send you a one-tap "Cheer" or a chat message.
5. To invite more people later, use **Invite More People** at the bottom of
   the Circle tab.

Each Circle member needs their own build of the app installed via Xcode
(from your Apple ID's free provisioning, everyone re-installs it themselves
every 7 days the same way you do) — or, once you're comfortable with it,
distribute a build via TestFlight instead, which needs the paid Developer
Program (see below).

## Notes on notifications and cost

- **Personal habit reminders** (the ones you set for yourself) are **local**
  notifications — free, no account requirements, work with any Apple ID.
- **Circle notifications** ("Sarah sent you a message", "Sarah just hit her
  goal!") are ideally delivered via a **silent CloudKit push** the instant
  something changes, even if the app is closed. That requires the **Push
  Notifications** capability, which Apple only issues to a **paid Apple
  Developer Program membership ($99/year)** — a free "Personal Team" cannot
  add this capability.
  - **With a paid account**: fully wired up already — CloudKit subscriptions
    are created automatically, and the AppDelegate turns incoming silent
    pushes into local notification banners.
  - **With a free account**: Circle sync still works completely (creating a
    circle, publishing goals, chatting) — you just won't get an instant
    banner. Updates appear whenever the app is opened or foregrounded (it
    refreshes automatically), or via pull-to-refresh on the Circle tab.
- Before distributing beyond your own devices (e.g. via TestFlight), open
  [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/) for
  this container and deploy the schema from **Development** to
  **Production** — Development auto-creates the record types/indexes the
  first time you save data, but Production needs that explicit promotion.

## A note on CloudKit code

CloudKit's APIs are some of the trickiest in the SDK to get exactly right
without Xcode's live compiler and a real device to test sharing between two
Apple IDs. `CloudKitManager.swift` follows Apple's documented patterns for
`CKShare` creation/acceptance and record sync, but if Xcode flags a small
API mismatch (method name or parameter changed between SDK versions), it
should be a quick fix — share the exact error and it can be corrected.
