# Backend Changes Needed for Held Appointments

## Overview
The Flutter app now expects the backend to return a `held_at` timestamp when an appointment is marked as held via the "Record Outcome" operation. This timestamp should reflect when the outcomes were recorded.

## Required Backend Changes

### 1. Database Schema
Add a `held_at` column to the `appointments` table:

```sql
ALTER TABLE appointments ADD COLUMN held_at TIMESTAMP NULL;
```

### 2. API Response Structure
When returning appointment data (via `/appointments/{id}`, `/dashboard/summary`, etc.), include the `held_at` field:

```json
{
  "id": 1,
  "purpose": "Team Meeting",
  "appointment_date": "2026-09-21",
  "start_time": "10:30:00",
  "status": "held",
  "held_at": "2026-09-21T14:30:00.000000Z",
  ...
}
```

### 3. Record Outcome Endpoint
When the frontend calls the record outcome endpoint (likely `/appointments/{id}/record-outcome` or similar), the backend should:

1. Update the appointment status to "held"
2. Set the `held_at` timestamp to the current time
3. Save the discussion notes and action points

Example implementation (pseudo-code):

```php
// In your record outcome endpoint
public function recordOutcome(Request $request, $id)
{
    $appointment = Appointment::find($id);
    
    // Update appointment status and set held_at
    $appointment->status = 'held';
    $appointment->held_at = now(); // Current timestamp
    $appointment->discussion_notes = $request->discussion_notes;
    $appointment->save();
    
    // Save action points
    foreach ($request->action_points as $ap) {
        ActionPoint::create([
            'appointment_id' => $id,
            'description' => $ap['description'],
            'responsible_person' => $ap['responsible_person'],
            'due_date' => $ap['due_date'],
            'status' => $ap['status'],
        ]);
    }
    
    return response()->json(['success' => true]);
}
```

### 4. Dashboard Summary Endpoint
When returning held appointments in the dashboard summary, ensure the `held_at` field is included so the Flutter app can display the recording date/time:

```json
{
  "held": 5,
  "held_appointments": [
    {
      "id": 1,
      "purpose": "Team Meeting",
      "status": "held",
      "held_at": "2026-09-21T14:30:00.000000Z",
      ...
    }
  ]
}
```

## Frontend Implementation

The Flutter app has been updated to:

1. **Appointment Model**: Added `heldAt` field to parse the backend response
2. **Dashboard**: Held appointments now display "Held on [date] at [time]" using the `held_at` timestamp
3. **Appointment Details**: Shows "Recorded on [date] at [time]" for held appointments
4. **Sorting**: Held appointments are sorted by `held_at` (most recent first)

## Testing

After implementing the backend changes:

1. Create an upcoming appointment
2. Navigate to appointment details
3. Click "Record Outcome" and save discussion notes/action points
4. Verify the appointment status changes to "held"
5. Check that `held_at` is set in the database
6. In the Flutter app:
   - Click "Held" on the dashboard stat card
   - Verify the appointment shows the recording date/time
   - Open appointment details
   - Verify "Recorded on [date] at [time]" is displayed

## Notes

- The `held_at` field should be nullable (NULL for non-held appointments)
- The timestamp should be in ISO 8601 format (e.g., `2026-09-21T14:30:00.000000Z`)
- If `held_at` is not available, the Flutter app will fall back to showing the scheduled date/time
