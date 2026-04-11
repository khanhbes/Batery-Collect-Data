// ============================================================
// EV Logger Webhook — Movement + Charging (batch-ready)
// ============================================================
const SHEET_ID = '1oZZfQHMJbM8DxBWghc2hKqRHXnFDoQw7Mg0-MwIIRu0'; // Replace with your actual Google Sheet ID
const API_KEY = "4d7f6a2c9b1e43f8a5d0c2e7b9f1a6c34e8d2b7a5c1f9d6e0b3a7c2d8e4f1a9"; // khop DRIVE_WEBHOOK_API_KEY, de "" neu tat auth

const SHEET_MOVEMENT = "Movement";
const SHEET_CHARGING = "Charging";

const MOVEMENT_HEADERS = [
  "trip_id","timestamp_utc","elapsed_sec","sample_count",
  "speed_kmh","accel_ms2","distance_km",
  "latitude","longitude","altitude_m",
  "start_soc","end_soc","payload_kg","effective_payload_kg","passenger_on",
  "ambient_temp_c","weather_condition"
];

const CHARGING_HEADERS = [
  "charge_id","start_timestamp_utc","end_timestamp_utc",
  "start_soc","end_soc","delta_soc","duration_sec",
  "latitude","longitude","ambient_temp_c"
];

function doGet(e) {
  return jsonResponse({
    status: "ok",
    version: "2.1",
    message: "EV Logger webhook is running",
    targets: ["movement", "charging", "delete_movement"]
  });
}

function doPost(e) {
  try {
    const body = parseBody(e);

    // Auth: uu tien body.key, fallback query ?key=
    if (API_KEY !== "") {
      const suppliedKey = (body.key || (e.parameter && e.parameter.key) || "").toString();
      if (suppliedKey !== API_KEY) {
        return jsonResponse({ status: "error", message: "Unauthorized" });
      }
    }

    const target = (body.target || detectTarget(body)).toString();
    const ss = SpreadsheetApp.openById(SHEET_ID);

    if (target === "movement") {
      const records = Array.isArray(body.records)
        ? body.records
        : (body.record ? [body.record] : (body.trip_id ? [body] : [])); // fallback de tuong thich

      if (records.length === 0) {
        return jsonResponse({ status: "error", message: "No movement records" });
      }

      const accepted = appendMovementBatch(ss, records);
      return jsonResponse({ status: "ok", target: "movement", accepted: accepted });
    }

    if (target === "charging") {
      const record = body.record || body; // fallback de tuong thich
      const accepted = appendChargingSingle(ss, record);
      return jsonResponse({ status: "ok", target: "charging", accepted: accepted });
    }

    if (target === "delete_movement") {
      const tripId = (body.trip_id || "").toString();
      if (!tripId) {
        return jsonResponse({ status: "error", message: "Missing trip_id for deletion" });
      }
      const deleted = deleteMovementByTripId(ss, tripId);
      return jsonResponse({ status: "ok", target: "delete_movement", deleted: deleted });
    }

    return jsonResponse({ status: "error", message: "Unknown target" });
  } catch (err) {
    return jsonResponse({ status: "error", message: String(err) });
  }
}

function parseBody(e) {
  const raw = (e && e.postData && e.postData.contents) ? e.postData.contents : "{}";
  try {
    return JSON.parse(raw);
  } catch (_) {
    throw new Error("Invalid JSON body");
  }
}

function appendMovementBatch(ss, records) {
  const sheet = ensureSheet(ss, SHEET_MOVEMENT, MOVEMENT_HEADERS);
  const existing = loadMovementKeys(sheet);

  const rows = [];
  records.forEach(function (rec) {
    if (!rec || typeof rec !== "object") return;

    const tripId = rec.trip_id;
    const sampleCount = rec.sample_count;

    // Only accept valid telemetry identity fields.
    if (!tripId || sampleCount === null || sampleCount === undefined) return;

    const key = buildMovementKey(rec);
    if (existing.has(key)) return;

    const row = MOVEMENT_HEADERS.map(function (h) {
      const v = rec[h];
      return (v === null || v === undefined) ? "" : v;
    });

    rows.push(row);
    existing.add(key);
  });

  if (rows.length === 0) {
    return 0;
  }

  // Sort batch by sample_count ascending before writing
  rows.sort(function (a, b) {
    return Number(a[3] || 0) - Number(b[3] || 0);
  });

  const startRow = sheet.getLastRow() + 1;
  const range = sheet.getRange(startRow, 1, rows.length, MOVEMENT_HEADERS.length);
  range.setValues(rows);

  return rows.length;
}

function appendChargingSingle(ss, rec) {
  const sheet = ensureSheet(ss, SHEET_CHARGING, CHARGING_HEADERS);
  if (!rec || typeof rec !== "object") {
    return 0;
  }

  const chargeId = String(rec.charge_id || "");
  if (!chargeId) {
    return 0;
  }

  const row = CHARGING_HEADERS.map(function (h) {
    const v = rec[h];
    return (v === null || v === undefined) ? "" : v;
  });

  // Upsert: if charge_id already exists, update that row; otherwise append
  const lastRow = sheet.getLastRow();
  if (lastRow > 1) {
    const data = sheet.getRange(2, 1, lastRow - 1, CHARGING_HEADERS.length).getValues();
    for (var i = 0; i < data.length; i++) {
      if (String(data[i][0] || "") === chargeId) {
        // Found existing row → update in-place
        sheet.getRange(i + 2, 1, 1, CHARGING_HEADERS.length).setValues([row]);
        return 1;
      }
    }
  }

  // Not found → append new row
  sheet.appendRow(row);
  return 1;
}

function buildMovementKey(rec) {
  return String(rec.trip_id || "") + "|" + String(rec.sample_count || "");
}

function buildChargingKey(rec) {
  const chargeId = String(rec.charge_id || "");
  if (chargeId) return chargeId;
  return String(rec.start_timestamp_utc || "");
}

function loadMovementKeys(sheet) {
  const set = new Set();
  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return set;

  const values = sheet.getRange(2, 1, lastRow - 1, MOVEMENT_HEADERS.length).getValues();
  values.forEach(function (row) {
    // trip_id = col 0 (index 0), sample_count = col 3 (index 3)
    const rec = { trip_id: row[0], sample_count: row[3] };
    const key = buildMovementKey(rec);
    if (key !== "|") set.add(key);
  });
  return set;
}

function loadChargingKeys(sheet) {
  const set = new Set();
  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return set;

  const values = sheet.getRange(2, 1, lastRow - 1, CHARGING_HEADERS.length).getValues();
  values.forEach(function (row) {
    const rec = { charge_id: row[0], start_timestamp_utc: row[1] };
    const key = buildChargingKey(rec);
    if (key) set.add(key);
  });
  return set;
}

function ensureSheet(ss, sheetName, headers) {
  let sheet = ss.getSheetByName(sheetName);
  if (!sheet) sheet = ss.insertSheet(sheetName);

  if (sheet.getLastRow() === 0) {
    sheet.appendRow(headers);
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function detectTarget(body) {
  if (Array.isArray(body.records)) return "movement";
  if (body.record && body.record.charge_id) return "charging";
  if (body.record && body.record.trip_id) return "movement";
  if (body.charge_id) return "charging";
  if (body.trip_id) return "movement";
  return "unknown";
}

function deleteMovementByTripId(ss, tripId) {
  const sheet = ss.getSheetByName(SHEET_MOVEMENT);
  if (!sheet) return 0;

  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return 0;

  const data = sheet.getRange(2, 1, lastRow - 1, MOVEMENT_HEADERS.length).getValues();
  const keep = [];
  let deleted = 0;

  data.forEach(function (row) {
    if (String(row[0] || "") === tripId) {
      deleted++;
    } else {
      keep.push(row);
    }
  });

  if (deleted === 0) return 0;

  sheet.getRange(2, 1, lastRow - 1, MOVEMENT_HEADERS.length).clearContent();
  if (keep.length > 0) {
    sheet.getRange(2, 1, keep.length, MOVEMENT_HEADERS.length).setValues(keep);
  }
  return deleted;
}

function jsonResponse(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

// ============================================================
// Maintenance functions — run manually from Apps Script editor
// ============================================================

/**
 * Remove duplicate movement rows (by trip_id|sample_count).
 * Run from Script Editor > maintenanceDedupeMovement
 */
function maintenanceDedupeMovement() {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheet = ss.getSheetByName(SHEET_MOVEMENT);
  if (!sheet) return;

  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return;

  const data = sheet.getRange(2, 1, lastRow - 1, MOVEMENT_HEADERS.length).getValues();
  const seen = new Set();
  const unique = [];

  data.forEach(function (row) {
    const key = String(row[0] || "") + "|" + String(row[3] || "");
    if (key !== "|" && !seen.has(key)) {
      seen.add(key);
      unique.push(row);
    }
  });

  if (unique.length === data.length) {
    Logger.log("No duplicates found in Movement");
    return;
  }

  sheet.getRange(2, 1, lastRow - 1, MOVEMENT_HEADERS.length).clearContent();
  if (unique.length > 0) {
    sheet.getRange(2, 1, unique.length, MOVEMENT_HEADERS.length).setValues(unique);
  }
  Logger.log("Movement: removed " + (data.length - unique.length) + " duplicates");
}

/**
 * Remove duplicate charging rows (by charge_id).
 */
function maintenanceDedupeCharging() {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheet = ss.getSheetByName(SHEET_CHARGING);
  if (!sheet) return;

  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return;

  const data = sheet.getRange(2, 1, lastRow - 1, CHARGING_HEADERS.length).getValues();
  const seen = new Set();
  const unique = [];

  data.forEach(function (row) {
    const key = String(row[0] || "");
    if (key && !seen.has(key)) {
      seen.add(key);
      unique.push(row);
    }
  });

  if (unique.length === data.length) {
    Logger.log("No duplicates found in Charging");
    return;
  }

  sheet.getRange(2, 1, lastRow - 1, CHARGING_HEADERS.length).clearContent();
  if (unique.length > 0) {
    sheet.getRange(2, 1, unique.length, CHARGING_HEADERS.length).setValues(unique);
  }
  Logger.log("Charging: removed " + (data.length - unique.length) + " duplicates");
}

/**
 * Re-sort all movement data by trip_id (asc) then sample_count (asc).
 */
function maintenanceNormalizeMovementOrder() {
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const sheet = ss.getSheetByName(SHEET_MOVEMENT);
  if (!sheet) return;

  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return;

  const data = sheet.getRange(2, 1, lastRow - 1, MOVEMENT_HEADERS.length).getValues();
  data.sort(function (a, b) {
    const cmp = String(a[0] || "").localeCompare(String(b[0] || ""));
    if (cmp !== 0) return cmp;
    return Number(a[3] || 0) - Number(b[3] || 0);
  });

  sheet.getRange(2, 1, data.length, MOVEMENT_HEADERS.length).setValues(data);
  Logger.log("Movement: re-sorted " + data.length + " rows");
}