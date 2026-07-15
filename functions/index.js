/**
 * SmartDrip Cloud Functions
 * =========================
 * Two functions:
 *
 * 1. onSensorWrite  — triggered on every write to /smartdrip/sensor.
 *    Uses change.before / change.after to detect STATE TRANSITIONS
 *    (not every single write), so alerts only fire once per event:
 *      - Pump turned ON / OFF (automatic)
 *      - Soil crossed into "very dry / critical" range
 *      - Temperature crossed into "high" range
 *      - Water tank crossed into "low" range
 *      - Device reconnected (if it was previously marked offline)
 *
 * 2. checkDeviceOffline — scheduled function, runs every 5 minutes.
 *    Compares smartdrip/status/lastSeen against now(); if stale beyond
 *    the threshold, marks the device offline and sends one alert
 *    (won't repeat until it reconnects).
 *
 * Required ESP32-side data (written to /smartdrip/sensor):
 *   soil, temperature, humidity, pumpStatus (bool), waterLevel (optional)
 *
 * Deploy:
 *   cd functions && npm install firebase-admin firebase-functions
 *   firebase deploy --only functions
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// ================= THRESHOLDS =================

const VERY_DRY_THRESHOLD = 15.0; // % — critical warning
const HIGH_TEMP_THRESHOLD = 38.0; // °C
const LOW_WATER_THRESHOLD = 20.0; // % — only used if waterLevel field exists

// Device is considered offline if no sensor write in this window
const OFFLINE_THRESHOLD_MS = 10 * 60 * 1000; // 10 minutes

// Minimum time between two alerts of the SAME type, so a value
// hovering right at a threshold doesn't spam repeated alerts.
const ALERT_COOLDOWN_MS = 15 * 60 * 1000; // 15 minutes

const db = admin.database();

// ================= HELPERS =================

async function withinCooldown(alertType, now) {
    const ref = db.ref(`smartdrip/meta/lastAlert/${alertType}`);
    const snap = await ref.get();
    const last = snap.exists() ? snap.val() : 0;

    if (now - last < ALERT_COOLDOWN_MS) return true;

    await ref.set(now);
    return false;
}

async function sendAlert({ type, title, message, soil }) {
    const now = Date.now();

    if (await withinCooldown(type, now)) {
        console.log(`Skipping ${type}: still in cooldown`);
        return;
    }

    // 1. Write alert record — the Flutter app's AlertService listens to
    //    this path and shows a local notification while in foreground.
    await db.ref("smartdrip/alerts").push({
        type,
        title,
        message,
        soil: soil ?? null,
        timestamp: now,
    });

    // 2. Send FCM push — reaches the device even if the app is closed.
    const tokensSnap = await db.ref("smartdrip/deviceTokens").get();

    if (!tokensSnap.exists()) {
        console.log("No device tokens registered, skipping FCM push");
        return;
    }

    const tokens = Object.keys(tokensSnap.val());
    if (tokens.length === 0) return;

    try {
        const response = await admin.messaging().sendEachForMulticast({
            notification: { title, body: message },
            tokens,
        });

        console.log(
            `[${type}] FCM sent: ${response.successCount} success, ${response.failureCount} failed`
        );

        response.responses.forEach((resp, idx) => {
            if (!resp.success) {
                const code = resp.error && resp.error.code;
                if (
                    code === "messaging/invalid-registration-token" ||
                    code === "messaging/registration-token-not-registered"
                ) {
                    db.ref(`smartdrip/deviceTokens/${tokens[idx]}`).remove();
                }
            }
        });
    } catch (err) {
        console.error(`Error sending FCM for ${type}:`, err);
    }
}

// ================= SENSOR WRITE TRIGGER =================

exports.onSensorWrite = functions.database
    .ref("/smartdrip/sensor")
    .onWrite(async (change, context) => {
        const before = change.before.val() || {};
        const after = change.after.val();

        if (!after) return null;

        const now = Date.now();

        const soil = Number(after.soil);
        const prevSoil = before.soil !== undefined ? Number(before.soil) : null;

        const temp = Number(after.temperature);
        const prevTemp =
            before.temperature !== undefined ? Number(before.temperature) : null;

        const pumpStatus = after.pumpStatus;
        const prevPumpStatus = before.pumpStatus;

        const waterLevel =
            after.waterLevel !== undefined ? Number(after.waterLevel) : null;
        const prevWaterLevel =
            before.waterLevel !== undefined ? Number(before.waterLevel) : null;

        // ---------- Mark device as seen (for offline/reconnect tracking) ----------
        const statusSnap = await db.ref("smartdrip/status").get();
        const wasOnline = statusSnap.exists() ? statusSnap.val().online : true;

        await db.ref("smartdrip/status").update({
            lastSeen: now,
            online: true,
        });

        if (wasOnline === false) {
            await sendAlert({
                type: "DEVICE_RECONNECTED",
                title: "🔋 Device Reconnected",
                message: "SmartDrip device has reconnected.",
            });
        }

        // ---------- Pump ON / OFF (edge-triggered on boolean change) ----------
        if (
            typeof pumpStatus === "boolean" &&
            pumpStatus !== prevPumpStatus &&
            !isNaN(soil)
        ) {
            if (pumpStatus === true) {
                await sendAlert({
                    type: "PUMP_ON",
                    title: "💧 Pump ON (Automatic)",
                    message: `Soil moisture is low (${soil.toFixed(
                        0
                    )}%). Irrigation started automatically.`,
                    soil,
                });
            } else {
                await sendAlert({
                    type: "PUMP_OFF",
                    title: "✅ Pump OFF (Automatic)",
                    message: `Soil moisture reached the target level (${soil.toFixed(
                        0
                    )}%). Irrigation stopped.`,
                    soil,
                });
            }
        }

        // ---------- Very Dry Soil (edge-triggered crossing into critical range) ----------
        if (
            !isNaN(soil) &&
            soil < VERY_DRY_THRESHOLD &&
            (prevSoil === null || prevSoil >= VERY_DRY_THRESHOLD)
        ) {
            await sendAlert({
                type: "VERY_DRY",
                title: "⚠️ Very Dry Soil",
                message: `Warning: Soil moisture is critically low (${soil.toFixed(
                    0
                )}%).`,
                soil,
            });
        }

        // ---------- High Temperature (edge-triggered crossing threshold) ----------
        if (
            !isNaN(temp) &&
            temp >= HIGH_TEMP_THRESHOLD &&
            (prevTemp === null || prevTemp < HIGH_TEMP_THRESHOLD)
        ) {
            await sendAlert({
                type: "HIGH_TEMP",
                title: "🌡️ High Temperature",
                message: `Temperature has reached ${temp.toFixed(0)}°C.`,
            });
        }

        // ---------- Water Tank Low (only if waterLevel field is present) ----------
        if (
            waterLevel !== null &&
            !isNaN(waterLevel) &&
            waterLevel < LOW_WATER_THRESHOLD &&
            (prevWaterLevel === null || prevWaterLevel >= LOW_WATER_THRESHOLD)
        ) {
            await sendAlert({
                type: "LOW_WATER_TANK",
                title: "💦 Water Tank Low",
                message: "Water tank is running low.",
            });
        }

        return null;
    });

// ================= OFFLINE DETECTION (SCHEDULED) =================

exports.checkDeviceOffline = functions.pubsub
    .schedule("every 5 minutes")
    .onRun(async (context) => {
        const statusSnap = await db.ref("smartdrip/status").get();

        if (!statusSnap.exists()) return null;

        const status = statusSnap.val();
        const lastSeen = status.lastSeen || 0;
        const now = Date.now();

        // Already marked offline — nothing new to do until it reconnects
        if (status.online === false) return null;

        if (now - lastSeen > OFFLINE_THRESHOLD_MS) {
            await db.ref("smartdrip/status/online").set(false);

            await sendAlert({
                type: "DEVICE_OFFLINE",
                title: "📶 ESP32 Offline",
                message: "SmartDrip device is offline.",
            });
        }

        return null;
    });