# API & Structured AI Contracts Reference

## 1. Natural Language Parsing Contract (Message-to-Reminder)

### Request Payload (`POST /api/v1/parse`)
```json
{
  "text": "Kal bikel 5tay mayer sathe doctor",
  "client_time_utc": "2026-11-06T00:50:00Z",
  "timezone": "Asia/Dhaka",
  "language_hint": "bn-BD"
}
```

### Response Schema (`200 OK`)
```json
{
  "intent": "create_reminder",
  "confidence": 0.94,
  "data": {
    "title": "Doctor with Mom",
    "due_at_utc": "2026-11-07T11:00:00Z",
    "timezone": "Asia/Dhaka",
    "repeat_rule": {
      "frequency": "none"
    },
    "category_suggestion": "Health",
    "priority": 1,
    "needs_clarification": false,
    "clarification_prompt": null
  }
}
```

## 2. Document OCR Labeling Contract

### Request Payload (`POST /api/v1/ocr/label`)
```json
{
  "extracted_snippets": [
    "Government of the People's Republic of Bangladesh",
    "Date of Expiry: 14 AUG 2029",
    "Passport No: A01234567"
  ]
}
```

### Response Schema (`200 OK`)
```json
{
  "document_type": "Passport",
  "suggested_category": "Identity",
  "detected_dates": [
    {
      "label": "Expiry Date",
      "date": "2029-08-14",
      "confidence": 0.98,
      "recommended_alerts": [90, 30, 7]
    }
  ]
}
```
