const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// -------- helpers --------
function toNumber(v) {
  if (v === null || v === undefined) return null;
  if (typeof v === "number") return v;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function computeLevel(value, maxSafe, maxModerate) {
  if (value === null || maxSafe === null || maxModerate === null) return null;
  if (value > maxModerate) return "Unhealthy";
  if (value > maxSafe) return "Moderate";
  return null; // Safe
}

// personalAirAlerts Map only
// - إذا موجودة وفيها قيم: لازم يكون true
// - إذا غير موجودة أو فاضية: يبغى الكل
function userWantsPollutant(userData, pollutantId) {
  const prefs = userData.personalAirAlerts;

  if (!prefs || typeof prefs !== "object" || Array.isArray(prefs)) return true;

  const keys = Object.keys(prefs);
  if (keys.length === 0) return true;

  return prefs[pollutantId] === true;
}

function readTimeOfDay(obj) {
  if (!obj || typeof obj !== "object") return null;
  const h = Number(obj.hour);
  const m = Number(obj.minute);
  if (!Number.isFinite(h) || !Number.isFinite(m)) return null;
  return { hour: h, minute: m };
}

function isNowInQuietHours(quietHours, startObj, endObj) {
  if (!quietHours) return false;

  const start = readTimeOfDay(startObj);
  const end = readTimeOfDay(endObj);
  if (!start || !end) return false;

  const now = new Date();
  const nowM = now.getHours() * 60 + now.getMinutes();
  const startM = start.hour * 60 + start.minute;
  const endM = end.hour * 60 + end.minute;

  // يعبر منتصف الليل
  if (startM > endM) return nowM >= startM || nowM <= endM;

  return nowM >= startM && nowM <= endM;
}

function templateId(pollutantId, level) {
  return `${pollutantId}_${level.toLowerCase()}`; // PM2_5_unhealthy
}

// -------- main function --------
exports.generateAlertsOnAirUpdate = functions.firestore
  .document("air_quality_data/{locationId}")
  .onWrite(async (change, context) => {
    const locationId = context.params.locationId;

    if (!change.after.exists) return null;

    const afterData = change.after.data() || {};
    const beforeData = change.before.exists ? change.before.data() || {} : {};

    const pollutantIds = ["PM2_5", "PM10", "O3", "CO", "SO2"];

    // إذا ما تغيرت قيم الملوثات -> لا تسوي شيء
    let changedAny = false;
    for (const pid of pollutantIds) {
      if (beforeData[pid] !== afterData[pid]) {
        changedAny = true;
        break;
      }
    }
    if (!changedAny) return null;

    // thresholds مرة وحدة
    const thSnap = await db.collection("thresholds").get();
    const thresholds = {};
    thSnap.forEach((doc) => {
      thresholds[doc.id] = doc.data();
    });

    // احسب مستوى كل ملوث
    const pollutantResult = {}; // pid -> {value, level}
    for (const pid of pollutantIds) {
      const value = toNumber(afterData[pid]);
      const th = thresholds[pid];
      if (!th) continue;

      const maxSafe = toNumber(th.max_safe);
      const maxModerate = toNumber(th.max_moderate);

      const level = computeLevel(value, maxSafe, maxModerate);
      pollutantResult[pid] = { value, level };
    }

    // users في نفس اللوكيشن
    const usersSnap = await db
      .collection("users")
      .where("locationId", "==", locationId)
      .get();

    const batch = db.batch();
    let writes = 0;

    for (const u of usersSnap.docs) {
      const userUid = u.id;
      const userData = u.data() || {};

      // quiet hours
      const quietHours = userData.quietHours === true;
      if (isNowInQuietHours(quietHours, userData.quietStart, userData.quietEnd)) {
        continue;
      }

      for (const pid of pollutantIds) {
        // preferences
        if (!userWantsPollutant(userData, pid)) continue;

        const r = pollutantResult[pid];
        if (!r) continue;

        const { value, level } = r;

        // Safe -> ما نرسل
        if (level === null) continue;

        // ✅ docId ثابت داخل alerts (بدون كولكشن جديد)
        const alertDocId = `${userUid}_${locationId}_${pid}`;
        const alertRef = db.collection("alerts").doc(alertDocId);

        // اقرأ آخر level المخزن في نفس doc
        const prev = await alertRef.get();
        const lastLevel = prev.exists ? (prev.data().alertLevel ?? null) : null;

        // إذا نفس الليفل -> لا نكرر
        if (lastLevel === level) continue;

        // template
        const tplDoc = await db.collection("alert_templates").doc(templateId(pid, level)).get();
        const tpl = tplDoc.exists ? tplDoc.data() : null;

        const title = (tpl?.title ?? `${pid} ${level}`).toString();
        const message = (tpl?.message ?? `${pid} is ${level}`).toString();

        batch.set(
          alertRef,
          {
            userUid,
            locationId,
            pollutantId: pid,
            pollutantType: pid, // خليها pid (PM2_5) عشان ثابتة
            value,
            alertLevel: level,
            title,
            message,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        writes++;
      }
    }

    if (writes > 0) {
      await batch.commit();
    }

    return null;
  });