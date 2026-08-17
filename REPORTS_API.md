# Reports API contract

The Flutter Reports screen calls these authenticated endpoints with the same
Bearer token already used by the appointment APIs.

## `GET /api/reports?from=YYYY-MM-DD&to=YYYY-MM-DD`

Scope every result to the authenticated user's appointments. Dates are
inclusive. Return `200` with JSON in this shape:

```json
{
  "appointments_held": 12,
  "people_met": 15,
  "actions_closed": 9,
  "actions_total": 14,
  "report_items": [
    { "label": "Appointment log with dates, times & status" }
  ],
  "appointments": [
    {
      "id": 42,
      "title": "Legacy Motors — progress review",
      "date": "2026-07-09",
      "people": ["Robert K.", "Sarah A."],
      "action_points": 2,
      "status": "held"
    }
  ]
}
```

`appointment_log` may be returned instead of `appointments`; the app accepts
either. Status values should normally be `held`, `missed`, or `completed`.

## `GET /api/reports/export?from=YYYY-MM-DD&to=YYYY-MM-DD&format=pdf`

Use the same authorization and date filtering. Return a rendered PDF with a
`200` response, `Content-Type: application/pdf`, and preferably a
`Content-Disposition` filename. The mobile client opens the native share sheet
with this file, enabling Save/Print/email/WhatsApp where installed.

Return a JSON `{ "message": "..." }` for validation or authorization errors;
the client displays that message to the user.
