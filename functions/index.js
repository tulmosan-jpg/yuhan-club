/**
 * yuhan_club 서버 푸시 알림 (Cloud Functions v2).
 *
 * 이벤트 → 수신자:
 *  - reports/{id} 생성            → 운영진(admins)          (n_new_report)
 *  - groups/{gid}/attendance_dates/{day} 생성 → 그룹원      (n_schedule_added)
 *  - groups/{gid}/attendance/{uid}/rsvp/{day} 생성(불참) → 운영진 (n_rsvp_declined)
 *
 * 수신자 필터: users/{uid}.notif_enabled 및 해당 종류 토글이 false 면 제외.
 * FCM 토큰은 users/{uid}.fcmTokens 배열. 무효 토큰은 발송 후 정리한다.
 *
 * 비용 안전장치: maxInstances 로 동시 실행 상한 → 폭주 시에도 과금 억제.
 */
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// 동시 실행 상한(비용 폭주 방지).
setGlobalOptions({maxInstances: 5});

/**
 * 주어진 uid 들 중, 마스터 알림 + 해당 종류 토글이 켜진 사용자의
 * FCM 토큰을 모아 { token: uid } 매핑으로 반환.
 */
async function collectTokens(uids, prefKey, excludeUid) {
  const uniq = [...new Set(uids)].filter((u) => u && u !== excludeUid);
  if (uniq.length === 0) return {};
  const snaps = await db.getAll(
      ...uniq.map((u) => db.collection("users").doc(u)),
  );
  const map = {};
  for (const snap of snaps) {
    if (!snap.exists) continue;
    const d = snap.data() || {};
    if (d.notif_enabled === false) continue;
    if (prefKey && d[prefKey] === false) continue;
    const tokens = Array.isArray(d.fcmTokens) ? d.fcmTokens : [];
    for (const t of tokens) map[t] = snap.id;
  }
  return map;
}

/** admins 컬렉션의 uid 목록. */
async function adminUids() {
  const snap = await db.collection("admins").get();
  return snap.docs.map((d) => d.id);
}

/** 그룹 멤버 uid 목록. */
async function groupMemberUids(gid) {
  const snap = await db.collection("groups").doc(gid)
      .collection("members").get();
  return snap.docs.map((d) => d.id);
}

/** 토큰맵으로 멀티캐스트 발송 + 무효 토큰 정리. */
async function sendTo(tokenMap, title, body, data) {
  const tokens = Object.keys(tokenMap);
  if (tokens.length === 0) {
    logger.info("수신 대상 토큰 없음", {title});
    return;
  }
  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {title, body},
    data: data || {},
    android: {priority: "high"},
  });

  // 무효 토큰 정리(users.fcmTokens 에서 arrayRemove).
  const toRemove = {}; // uid -> [tokens]
  res.responses.forEach((r, i) => {
    if (r.success) return;
    const code = r.error && r.error.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/invalid-argument"
    ) {
      const token = tokens[i];
      const uid = tokenMap[token];
      (toRemove[uid] = toRemove[uid] || []).push(token);
    }
  });
  const cleanups = Object.entries(toRemove).map(([uid, ts]) =>
    db.collection("users").doc(uid).set({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...ts),
    }, {merge: true}),
  );
  await Promise.all(cleanups);
  logger.info("푸시 발송 완료", {
    title, ok: res.successCount, fail: res.failureCount,
  });
}

// ── 새 보고서 → 운영진 ─────────────────────────────────────────
exports.onReportCreated = onDocumentCreated("reports/{id}", async (event) => {
  const data = event.data && event.data.data();
  if (!data) return;
  const author = data.authorName || data.userName || "회원";
  const tokens = await collectTokens(
      await adminUids(), "n_new_report", data.authorId);
  await sendTo(
      tokens,
      "새 동아리 보고서",
      `${author} 님이 보고서를 제출했어요.`,
      {type: "new_report", reportId: event.params.id},
  );
});

// ── 새 그룹 일정 → 그룹원 ──────────────────────────────────────
exports.onGroupScheduleCreated = onDocumentCreated(
    "groups/{gid}/attendance_dates/{day}",
    async (event) => {
      const gid = event.params.gid;
      const tokens = await collectTokens(
          await groupMemberUids(gid), "n_schedule_added");
      await sendTo(
          tokens,
          "새 모임 일정이 등록됐어요",
          "출석 일정을 확인하고 참석 여부를 응답해 주세요.",
          {type: "schedule_added", groupId: gid, day: event.params.day},
      );
    },
);

// ── RSVP 불참 → 운영진 ─────────────────────────────────────────
exports.onRsvpCreated = onDocumentCreated(
    "groups/{gid}/attendance/{uid}/rsvp/{day}",
    async (event) => {
      const data = event.data && event.data.data();
      if (!data || data.available !== false) return; // 불참만 알림
      const name = data.userName || "회원";
      const reason = data.reason ? ` (${data.reason})` : "";
      const tokens = await collectTokens(
          await adminUids(), "n_rsvp_declined");
      await sendTo(
          tokens,
          "참석 불가 응답",
          `${name} 님이 ${event.params.day} 모임에 불참으로 응답했어요.${reason}`,
          {type: "rsvp_declined", groupId: event.params.gid},
      );
    },
);
