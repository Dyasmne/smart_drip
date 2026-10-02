/**
 * SmartDrip Cloud Functions
 * =========================
 *
 * 1. onSensorWrite
 *    - Triggered whenever /smartdrip/sensor is updated.
 *    - Updates device online status and lastSeen.
 *    - Sends alerts only when important values change/cross thresholds.
 *
 * 2. checkDeviceOffline
 *    - Runs every 5 minutes.
 *    - Checks if the ESP32 has stopped sending sensor data.
 *    - Sends ONE offline notification per offline event.
 *    - Does NOT repeat every hour while the device remains offline.
 *    - When the ESP32 reconnects, the offline state is reset.
 *
 * Required ESP32 sensor data:
 *   soil
 *   pumpStatus
 *   waterLevel (optional)
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.database();

// ================= THRESHOLDS =================

const VERY_DRY_THRESHOLD = 15.0;
const LOW_WATER_THRESHOLD = 20.0;

// ESP32 is considered offline if no sensor update
// has been received for more than 10 minutes.
const OFFLINE_THRESHOLD_MS = 10 * 60 * 1000;

// Cooldown for normal alerts.
const ALERT_COOLDOWN_MS = 15 * 60 * 1000;

// ================= HELPERS =================

async function withinCooldown(alertType, now) {
    const ref = db.ref(`smartdrip/meta/lastAlert/${alertType}`);
    const snap = await ref.get();

    const last = snap.exists() ? Number(snap.val()) : 0;

    if (now - last < ALERT_COOLDOWN_MS) {
        return true;
    }

    await ref.set(now);

    return false;
}

// ================= GET FCM TOKENS =================

async function getFcmTokens() {
    const tokenSet = new Set();

    // -------------------------------------------------
    // OLD / DIRECT TOKEN PATH
    // smartdrip/deviceTokens/{token}: true
    // -------------------------------------------------

    const deviceTokensSnap = await db
        .ref("smartdrip/deviceTokens")
        .get();

    if (deviceTokensSnap.exists()) {
        const deviceTokens = deviceTokensSnap.val();

        if (deviceTokens && typeof deviceTokens === "object") {
            Object.keys(deviceTokens).forEach((token) => {
                if (token) {
                    tokenSet.add(token);
                }
            });
        }
    }

    // -------------------------------------------------
    // CURRENT USER TOKEN PATH
    // smartdrip/users/{uid}/fcmToken
    // -------------------------------------------------

    const usersSnap = await db
        .ref("smartdrip/users")
        .get();

    if (usersSnap.exists()) {
        const users = usersSnap.val();

        if (users && typeof users === "object") {
            Object.values(users).forEach((user) => {
                if (
                    user &&
                    typeof user === "object" &&
                    typeof user.fcmToken === "string" &&
                    user.fcmToken.trim() !== ""
                ) {
                    tokenSet.add(user.fcmToken.trim());
                }
            });
        }
    }

    return Array.from(tokenSet);
}

// ================= SEND ALERT =================

async function sendAlert({
    type,
    title,
    message,
    soil,
}) {
    const now = Date.now();

    // DEVICE_OFFLINE is controlled by device state,
    // not by a time-based cooldown.
    //
    // Other alert types still use the normal cooldown.
    if (type !== "DEVICE_OFFLINE") {
        if (await withinCooldown(type, now)) {
            console.log(
                `Skipping ${type}: still in cooldown`
            );

            return;
        }
    }

    // -------------------------------------------------
    // SAVE ALERT TO FIREBASE
    // -------------------------------------------------

    await db.ref("smartdrip/alerts").push({
        type,
        title,
        message,
        soil: soil ?? null,
        timestamp: now,
    });

    // -------------------------------------------------
    // GET ALL FCM TOKENS
    // -------------------------------------------------

    const tokens = await getFcmTokens();

    if (tokens.length === 0) {
        console.log(
            "No FCM tokens registered. Skipping FCM push."
        );

        return;
    }

    // -------------------------------------------------
    // SEND FCM PUSH
    // -------------------------------------------------

    try {
        const response =
            await admin.messaging().sendEachForMulticast({
                notification: {
                    title,
                    body: message,
                },

                tokens,
            });

        console.log(
            `[${type}] FCM sent: ` +
            `${response.successCount} success, ` +
            `${response.failureCount} failed`
        );

        // -------------------------------------------------
        // REMOVE INVALID TOKENS
        // -------------------------------------------------

        response.responses.forEach((resp, index) => {
            if (!resp.success) {
                const code =
                    resp.error &&
                    resp.error.code;

                if (
                    code ===
                        "messaging/invalid-registration-token" ||
                    code ===
                        "messaging/registration-token-not-registered"
                ) {
                    const invalidToken =
                        tokens[index];

                    console.log(
                        "Removing invalid FCM token."
                    );

                    db.ref(
                        `smartdrip/deviceTokens/${invalidToken}`
                    ).remove();
                }
            }
        });
    } catch (err) {
        console.error(
            `Error sending FCM for ${type}:`,
            err
        );
    }
}

// ================= SENSOR WRITE TRIGGER =================

exports.onSensorWrite = functions.database
    .ref("/smartdrip/sensor")
    .onWrite(async (change, context) => {
        const before =
            change.before.val() || {};

        const after =
            change.after.val();

        if (!after) {
            return null;
        }

        const now = Date.now();

        // -------------------------------------------------
        // SENSOR VALUES
        // -------------------------------------------------

        const soil =
            Number(after.soil);

        const prevSoil =
            before.soil !== undefined
                ? Number(before.soil)
                : null;

        const pumpStatus =
            after.pumpStatus;

        const prevPumpStatus =
            before.pumpStatus;

        const waterLevel =
            after.waterLevel !== undefined
                ? Number(after.waterLevel)
                : null;

        const prevWaterLevel =
            before.waterLevel !== undefined
                ? Number(before.waterLevel)
                : null;

        // -------------------------------------------------
        // MARK DEVICE ONLINE
        // -------------------------------------------------
        //
        // Every sensor write means the ESP32 is alive.
        // Setting online=true here resets the offline state.
        //

        const statusRef =
            db.ref("smartdrip/status");

        const statusSnap =
            await statusRef.get();

        const previousStatus =
            statusSnap.exists()
                ? statusSnap.val()
                : {};

        const wasOffline =
            previousStatus.online === false;

        await statusRef.update({
            lastSeen: now,
            online: true,
        });

        // -------------------------------------------------
        // DEVICE RECONNECTED
        // -------------------------------------------------

        if (wasOffline) {
            console.log(
                "ESP32 reconnected. Device is ONLINE again."
            );

            // Optional reconnect alert.
            //
            // Uncomment this section if you want
            // a notification when the ESP32 reconnects.
            //
            // await sendAlert({
            //     type: "DEVICE_RECONNECTED",
            //     title: "📶 ESP32 Reconnected",
            //     message:
            //         "SmartDrip device is back online.",
            // });
        }

        // -------------------------------------------------
        // PUMP ON / OFF
        // -------------------------------------------------

        if (
            typeof pumpStatus === "boolean" &&
            pumpStatus !== prevPumpStatus &&
            !isNaN(soil)
        ) {
            if (pumpStatus === true) {
                await sendAlert({
                    type: "PUMP_ON",
                    title: "💧 Pump ON (Automatic)",
                    message:
                        `Soil moisture is low ` +
                        `(${soil.toFixed(0)}%). ` +
                        `Irrigation started automatically.`,
                    soil,
                });
            } else {
                await sendAlert({
                    type: "PUMP_OFF",
                    title: "✅ Pump OFF (Automatic)",
                    message:
                        `Soil moisture reached ` +
                        `the target level ` +
                        `(${soil.toFixed(0)}%). ` +
                        `Irrigation stopped.`,
                    soil,
                });
            }
        }

        // -------------------------------------------------
        // VERY DRY SOIL
        // -------------------------------------------------

        if (
            !isNaN(soil) &&
            soil < VERY_DRY_THRESHOLD &&
            (
                prevSoil === null ||
                prevSoil >= VERY_DRY_THRESHOLD
            )
        ) {
            await sendAlert({
                type: "VERY_DRY",
                title: "⚠️ Very Dry Soil",
                message:
                    `Warning: Soil moisture is ` +
                    `critically low ` +
                    `(${soil.toFixed(0)}%).`,
                soil,
            });
        }

        // -------------------------------------------------
        // LOW WATER TANK
        // -------------------------------------------------

        if (
            waterLevel !== null &&
            !isNaN(waterLevel) &&
            waterLevel < LOW_WATER_THRESHOLD &&
            (
                prevWaterLevel === null ||
                prevWaterLevel >= LOW_WATER_THRESHOLD
            )
        ) {
            await sendAlert({
                type: "LOW_WATER_TANK",
                title: "💦 Water Tank Low",
                message:
                    "Water tank is running low.",
            });
        }

        return null;
    });

// ================= OFFLINE DETECTION =================

exports.checkDeviceOffline = functions.pubsub
    .schedule("every 5 minutes")
    .onRun(async (context) => {
        const statusRef =
            db.ref("smartdrip/status");

        const statusSnap =
            await statusRef.get();

        if (!statusSnap.exists()) {
            console.log(
                "No SmartDrip status found."
            );

            return null;
        }

        const status =
            statusSnap.val();

        const lastSeen =
            Number(status.lastSeen || 0);

        const now =
            Date.now();

        // -------------------------------------------------
        // ALREADY OFFLINE
        // -------------------------------------------------
        //
        // IMPORTANT:
        // If the device was already marked offline,
        // DO NOT send another notification.
        //
        // This means:
        //
        // 10 minutes offline = 1 notification
        // 1 hour offline = 0 additional notifications
        // 5 hours offline = 0 additional notifications
        //

        if (status.online === false) {
            console.log(
                "ESP32 is already OFFLINE."
            );

            console.log(
                "No repeat offline notification."
            );

            return null;
        }

        // -------------------------------------------------
        // CHECK LAST SEEN
        // -------------------------------------------------

        if (
            lastSeen > 0 &&
            now - lastSeen >
                OFFLINE_THRESHOLD_MS
        ) {
            console.log(
                "ESP32 has exceeded the offline threshold."
            );

            // -------------------------------------------------
            // MARK OFFLINE FIRST
            // -------------------------------------------------
            //
            // This is important.
            // We mark it offline BEFORE sending the alert.
            //
            // The next scheduled run will see:
            //
            // online === false
            //
            // and will stop immediately.
            //

            await statusRef.update({
                online: false,
                offlineSince: now,
            });

            // -------------------------------------------------
            // SEND ONE OFFLINE ALERT
            // -------------------------------------------------

            await sendAlert({
                type: "DEVICE_OFFLINE",
                title: "📶 ESP32 Offline",
                message:
                    "SmartDrip device is offline.",
            });

            console.log(
                "ESP32 marked OFFLINE."
            );

            console.log(
                "Offline notification sent ONCE."
            );
        }

        return null;
    });