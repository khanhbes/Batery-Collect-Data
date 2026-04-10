# Google Apps Script Webhook Configuration

## Setup Instructions

1. Create a new Google Apps Script project at https://script.google.com
2. Create a two sheets in the connected Google Sheet:
   - `Movement` (for location telemetry)
   - `Charging` (for charging sessions)
3. Copy the following code to `Code.gs` in your Apps Script project
4. Deploy as Web App:
   - Execute as: Your account
   - Who has access: Anyone
   - Note the deployment URL → set in `lib/src/config/app_secrets.dart` as `kMovementWebhookUrl` and `kChargingWebhookUrl`
5. Set API key in dashboard (or embed in Flutter config)

## Code.gs

```javascript
const SHEET_ID = 'YOUR_SHEET_ID_HERE'; // Replace with your Google Sheet ID
const API_KEY = 'YOUR_API_KEY_HERE'; // Set in Flutter config, or retrieve via PropertiesService
const MOVEMENT_SHEET = 'Movement';
const CHARGING_SHEET = 'Charging';

function doGet(e) {
  return ContentService.createTextOutput(
    JSON.stringify({status: 'ok', message: 'EV Logger webhook service running'})
  ).setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  try {
    const rawBody = e.postData.contents;
    const payload = JSON.parse(rawBody);

    // Extract API key from body or query params
    const apiKey = payload.key || e.parameter.key;
    if (!apiKey || apiKey !== API_KEY) {
      return sendResponse(401, {status: 'error', message: 'Unauthorized'});
    }

    const target = payload.target || 'unknown';
    
    if (target === 'movement' && payload.records && Array.isArray(payload.records)) {
      // Batch movement processing
      return handleBatchMovement(payload.records);
    } else if (target === 'charging' && payload.record) {
      // Single charging processing
      return handleSingleCharging(payload.record);
    } else {
      return sendResponse(400, {status: 'error', message: 'Invalid payload format'});
    }
  } catch (error) {
    Logger.log('Error: ' + error.toString());
    return sendResponse(500, {status: 'error', message: error.toString()});
  }
}

function handleBatchMovement(records) {
  try {
    const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(MOVEMENT_SHEET);
    if (!sheet) {
      return sendResponse(500, {status: 'error', message: 'Movement sheet not found'});
    }

    // Prepare rows for batch insert
    const rows = records.map(record => [
      new Date(record.timestamp || Date.now()),
      record.latitude || 0,
      record.longitude || 0,
      record.accuracy || 0,
      record.altitude || 0,
      record.speed || 0,
      record.heading || 0,
      record.soc || 0,
      record.payload_kg || 0,
      record.effective_payload_kg || 0,
      record.passenger_on ? 'Yes' : 'No',
      record.voltage || 0,
      record.current || 0,
      record.temperature || 0
    ]);

    // Get last row and append in batch
    const lastRow = sheet.getLastRow();
    const startRow = lastRow + 1;
    const range = sheet.getRange(startRow, 1, rows.length, rows[0].length);
    range.setValues(rows);

    return sendResponse(200, {
      status: 'ok',
      target: 'movement',
      accepted: records.length
    });
  } catch (error) {
    Logger.log('Batch movement error: ' + error.toString());
    return sendResponse(500, {status: 'error', message: error.toString()});
  }
}

function handleSingleCharging(record) {
  try {
    const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(CHARGING_SHEET);
    if (!sheet) {
      return sendResponse(500, {status: 'error', message: 'Charging sheet not found'});
    }

    const row = [
      new Date(record.start_time || Date.now()),
      new Date(record.end_time || Date.now()),
      record.start_soc || 0,
      record.end_soc || 0,
      record.duration_minutes || 0,
      record.energy_added_kwh || 0,
      record.location || '',
      record.charger_type || '',
      record.payload_kg || 0
    ];

    sheet.appendRow(row);

    return sendResponse(200, {
      status: 'ok',
      target: 'charging',
      accepted: 1
    });
  } catch (error) {
    Logger.log('Single charging error: ' + error.toString());
    return sendResponse(500, {status: 'error', message: error.toString()});
  }
}

function sendResponse(code, data) {
  return ContentService.createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
```

## Sheet Structure

### Movement Sheet
| Header | Type | Notes |
|--------|------|-------|
| timestamp | DateTime | ISO 8601 |
| latitude | Number | Degrees |
| longitude | Number | Degrees |
| accuracy | Number | Meters |
| altitude | Number | Meters |
| speed | Number | m/s |
| heading | Number | Degrees |
| soc | Number | % |
| payload_kg | Number | Base payload |
| effective_payload_kg | Number | With passenger |
| passenger_on | Text | Yes/No |
| voltage | Number | Volts |
| current | Number | Amps |
| temperature | Number | Celsius |

### Charging Sheet
| Header | Type | Notes |
|--------|------|-------|
| start_time | DateTime | ISO 8601 |
| end_time | DateTime | ISO 8601 |
| start_soc | Number | % |
| end_soc | Number | % |
| duration_minutes | Number | Session duration |
| energy_added_kwh | Number | Charged energy |
| location | Text | Charging location |
| charger_type | Text | Type/speed |
| payload_kg | Number | Vehicle payload |

## Webhook URL Format

After deploying the Apps Script:
- **Movement Webhook**: `https://script.google.com/macros/d/{DEPLOYMENT_ID}/usercopy`
- **Charging Webhook**: Same URL (target parameter differentiates)
- **API Key**: Set in Flutter via `kDriveWebhookApiKey` in `lib/src/config/app_secrets.dart`

## Request Format

### Batch Movement
```json
{
  "target": "movement",
  "key": "YOUR_API_KEY",
  "records": [
    {
      "timestamp": "2024-01-15T10:30:00Z",
      "latitude": 21.028511,
      "longitude": 105.852393,
      "accuracy": 5,
      "altitude": 20,
      "speed": 12.5,
      "heading": 180,
      "soc": 75,
      "payload_kg": 1500,
      "effective_payload_kg": 1565,
      "passenger_on": true,
      "voltage": 400,
      "current": 2.5,
      "temperature": 45
    },
    ...
  ]
}
```

### Single Charging
```json
{
  "target": "charging",
  "key": "YOUR_API_KEY",
  "record": {
    "start_time": "2024-01-15T08:00:00Z",
    "end_time": "2024-01-15T09:30:00Z",
    "start_soc": 20,
    "end_soc": 80,
    "duration_minutes": 90,
    "energy_added_kwh": 45,
    "location": "DC Fast Charger - Hà Nội",
    "charger_type": "150kW DC",
    "payload_kg": 1500
  }
}
```

## Response Format

Success (200):
```json
{
  "status": "ok",
  "target": "movement",
  "accepted": 20
}
```

Error (40x/50x):
```json
{
  "status": "error",
  "message": "Unauthorized"
}
```

## Testing

1. Deploy Apps Script and note the URL
2. Test with `doGet` (should return health-check JSON)
3. Test batch POST with curl:
```bash
curl -X POST "https://script.google.com/macros/d/{DEPLOYMENT_ID}/usercopy" \
  -H "Content-Type: application/json" \
  -d '{
    "target": "movement",
    "key": "YOUR_API_KEY",
    "records": [{...}]
  }'
```

## Troubleshooting

- **401 Unauthorized**: Check API key matches in Flutter config and Apps Script
- **Sheet not found**: Verify sheet names match (case-sensitive)
- **Redirect (302)**: Apps Script sometimes returns redirect → DriveSyncService now handles via Location header
- **Response invalid**: Ensure JSON response contains `"status": "ok"`
