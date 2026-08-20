# Taskly v1.0.0

First release. Flutter app with a Supabase backend.

## Features

**Teams and roles**
Create a team and become its admin, or join an existing team with an 8-character
invite code and become a member. Roles are per team, so the same user can be an
admin in one team and a member in another. Admins can view and copy their team's
invite code to share it.

**Tasks**
Admins create tasks with a title, description, assignee, priority and an
optional deadline, and can delete any task in their team. Members see only the
tasks assigned to them and move each one through the status flow:
pending, in progress, done.

**Priority**
Every task is low, medium or high, defaulting to medium. Priority is shown as a
chip on the task card, so it is visible on both the admin and member lists.

**Deadlines**
Deadlines are optional. A task counts as overdue when its deadline has passed
and it is not done. Overdue tasks are highlighted on the task card, and a banner
at the top of the admin dashboard and the member task list shows how many tasks
are past their deadline.

**Search and filter**
A filter bar above both task lists searches titles and descriptions and filters
by status and priority. The admin list also filters by assignee.

**Chat**
Each team has a group chat, and members can open a direct message with any other
member of the team. Messages arrive live without refreshing.

**Notifications**
In-app notifications while the app is running. Members are notified when a task
is assigned to them; admins are notified when a task they created changes status.

**Authentication**
Sign up and log in with email and password, or sign in with Google or Facebook.
Email confirmation is enabled. Forgot-password recovery sends a numeric code by
email, which is entered in the app to set a new password.

**Profile and settings**
The profile screen shows your name and email, every team you belong to with your
role, and all of your tasks across teams grouped by status. Settings lets you
edit your display name and change your password while signed in, which is
separate from the forgot-password flow.

## Install

The APK is debug-signed. Android will show an "unknown app" or "unsafe app"
warning during installation, and installs from unknown sources must be allowed
for the app doing the installing (usually your browser or file manager).

1. Download `Taskly-v1.0.0.apk` to the device.
2. Open it. If Android blocks the install, allow installs from unknown sources
   for that app when prompted, then open the APK again.
3. Accept the warning about the app not being from a known developer.

The app requests notification permission on first launch. Declining it disables
the in-app task notifications but leaves everything else working.

## Notes

- Notifications are delivered while the app is running. There is no background
  or push delivery.
- Google and Facebook sign-in are limited to accounts allowlisted in the
  provider consoles until those apps complete verification and review.
- The build is signed with the Flutter debug keystore and is not suitable for
  Play Store distribution.
