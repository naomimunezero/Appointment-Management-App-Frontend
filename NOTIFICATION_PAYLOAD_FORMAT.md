# Notification Payload Format for Deep Linking

This document describes the expected notification payload format for FCM push notifications to enable deep linking to specific screens in the Flutter app.

## Overview

The Flutter app uses a global navigator key to handle notification taps and navigate to the appropriate screen based on the notification type and data included in the payload.

## Notification Types and Required Data

### 1. Reminder
Opens the appointment details screen for the specific appointment.

**Type:** `reminder`

**Required Fields:**
- `type`: "reminder"
- `appointment_id`: Integer ID of the appointment

**Example Payload:**
```json
{
  "type": "reminder",
  "appointment_id": 123
}
```

**Destination:** `/appointment-details` with appointment ID

---

### 2. Missed Appointment Nudge
Opens the appointment details screen for the missed appointment.

**Type:** `missed_nudge`

**Required Fields:**
- `type`: "missed_nudge"
- `appointment_id`: Integer ID of the appointment

**Example Payload:**
```json
{
  "type": "missed_nudge",
  "appointment_id": 456
}
```

**Destination:** `/appointment-details` with appointment ID

---

### 3. Overdue Action Point
Opens the appointment details screen (could open action point screen if available in future).

**Type:** `overdue_action`

**Required Fields:**
- `type`: "overdue_action"
- `appointment_id`: Integer ID of the appointment
- `action_point_id`: Integer ID of the action point (optional, for future use)

**Example Payload:**
```json
{
  "type": "overdue_action",
  "appointment_id": 789,
  "action_point_id": 101
}
```

**Destination:** `/appointment-details` with appointment ID

---

### 4. Daily Summary
Opens the diary screen to show the day's appointments.

**Type:** `daily_summary`

**Required Fields:**
- `type`: "daily_summary"

**Example Payload:**
```json
{
  "type": "daily_summary"
}
```

**Destination:** `/diary`

---

### 5. Activity Alert
Opens the appointment details screen if appointment data is available, otherwise opens dashboard.

**Type:** `activity_alert`

**Required Fields:**
- `type": "activity_alert"
- `appointment_id`: Integer ID of the appointment (optional)

**Example Payload (with appointment):**
```json
{
  "type": "activity_alert",
  "appointment_id": 321
}
```

**Example Payload (without appointment):**
```json
{
  "type": "activity_alert"
}
```

**Destination:** `/appointment-details` if appointment_id is present, otherwise `/dashboard`

---

## Backend Implementation

When sending FCM notifications, include the payload in the `data` field of the FCM message:

### Example FCM Message Structure

```php
// Laravel example
$message = CloudMessage::new()
    ->withNotification([
        'title' => 'Appointment Reminder',
        'body' => 'Your meeting starts in 30 minutes',
    ])
    ->withData([
        'type' => 'reminder',
        'appointment_id' => 123,
    ]);
```

```javascript
// Node.js example
const message = {
  notification: {
    title: 'Appointment Reminder',
    body: 'Your meeting starts in 30 minutes',
  },
  data: {
    type: 'reminder',
    appointment_id: '123',
  },
};
```

## Important Notes

1. **Data vs Notification**: Use the `data` field for the payload, not the `notification` field. The `data` field is available even when the app is terminated.

2. **Type Consistency**: Ensure the `type` field exactly matches one of the supported types listed above.

3. **ID Format**: All IDs should be sent as strings in the FCM payload (FCM requirement), but the Flutter app will parse them as integers.

4. **Testing**: Test notification taps in all three app states:
   - App in foreground
   - App in background
   - App terminated (cold start)

## Future Enhancements

Potential future additions:
- Dedicated action point details screen for overdue action points
- Activity/audit log screen for activity alerts
- Custom notification screens for different notification types
