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
const {onCall, HttpsError} = require("firebase-functions/v2/https");
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

/** 호출자가 관리자(admins/{uid} 존재)인지 확인, 아니면 예외. */
async function assertAdmin(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const snap = await db.collection("admins").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "관리자만 사용할 수 있습니다.");
  }
  return uid;
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
      const topic = (event.data && event.data.data() &&
        event.data.data().topic) || "";
      const body = topic ?
        `주제: ${topic} — 참석 여부를 응답해 주세요.` :
        "출석 일정을 확인하고 참석 여부를 응답해 주세요.";
      const tokens = await collectTokens(
          await groupMemberUids(gid), "n_schedule_added");
      await sendTo(
          tokens,
          "새 모임 일정이 등록됐어요",
          body,
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

// ══ 리워드(더벤티 쿠폰) — 서버에서 자격/재고 검증 ══════════════════

const COFFEE_STREAK = 2; // 연속 출석 2회당 쿠폰 1개
const DRINK_NAMES = {
  peach: "제로 복숭아 아이스티",
  plum: "제로 매실 아이스티",
  americano: "아이스 아메리카노",
};

/** 'yyyy-MM-dd' (KST 기준 날짜 키). */
function dayKey(d) {
  const kst = new Date(d.getTime() + 9 * 3600 * 1000);
  const y = kst.getUTCFullYear();
  const m = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const day = String(kst.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

/** 예정일 기준 연속 출석(스케줄 최신순으로 훑어 결석에서 멈춤). */
function streakFromSchedule(scheduleKeys, attendedKeys, todayKey) {
  const attended = new Set(attendedKeys);
  const checkedInToday = attended.has(todayKey);
  const past = [...new Set(scheduleKeys)]
      .filter((k) => k <= todayKey && !(k === todayKey && !checkedInToday))
      .sort()
      .reverse();
  let streak = 0;
  for (const k of past) {
    if (attended.has(k)) streak++;
    else break;
  }
  return streak;
}

/** 사용자의 첫 그룹 기준 신뢰 스트릭을 서버 데이터로 재계산. */
async function trustedStreak(uid) {
  // 내가 속한 첫 그룹 찾기.
  const groupsSnap = await db.collection("groups").get();
  let gid = null;
  for (const g of groupsSnap.docs) {
    const m = await db.collection("groups").doc(g.id)
        .collection("members").doc(uid).get();
    if (m.exists) {
      gid = g.id;
      break;
    }
  }
  const todayKey = dayKey(new Date());
  if (!gid) return 0;
  const [datesSnap, ciSnap] = await Promise.all([
    db.collection("groups").doc(gid).collection("attendance_dates").get(),
    db.collection("groups").doc(gid).collection("attendance").doc(uid)
        .collection("checkins").get(),
  ]);
  const scheduleKeys = datesSnap.docs
      .map((d) => (d.data().date ? dayKey(d.data().date.toDate()) : null))
      .filter(Boolean);
  const attendedKeys = ciSnap.docs
      .map((d) => (d.data().date ? dayKey(d.data().date.toDate()) : null))
      .filter(Boolean);
  return streakFromSchedule(scheduleKeys, attendedKeys, todayKey);
}

// ── 쿠폰 발급(자격 재확인 + 재고 차감, 원자적) ──
exports.claimCoupon = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const drinkId = request.data && request.data.drinkId;
  if (!DRINK_NAMES[drinkId]) {
    throw new HttpsError("invalid-argument", "잘못된 음료입니다.");
  }

  const streak = await trustedStreak(uid);
  const earned = Math.floor(streak / COFFEE_STREAK);

  const userRef = db.collection("users").doc(uid);
  const cfgRef = db.collection("config").doc("rewards");
  const couponRef = db.collection("coupons").doc();

  await db.runTransaction(async (tx) => {
    const [userSnap, cfgSnap] = await Promise.all([
      tx.get(userRef), tx.get(cfgRef),
    ]);
    const u = userSnap.data() || {};
    const rewardUnits = u.rewardUnits || 0;
    const snapStreak = u.rewardStreakSnapshot || 0;
    const claimed = streak >= snapStreak ? rewardUnits : 0;
    if (earned - claimed < 1) {
      throw new HttpsError("failed-precondition", "받을 수 있는 리워드가 없습니다.");
    }
    const cfg = cfgSnap.data() || {};
    const stock = cfg.stock || {};
    const remaining = typeof stock[drinkId] === "number" ? stock[drinkId] : 0;
    if (remaining <= 0) {
      throw new HttpsError("resource-exhausted", "해당 음료 재고가 소진됐습니다.");
    }
    const newStock = Object.assign({}, stock);
    newStock[drinkId] = remaining - 1;
    tx.set(cfgRef, {stock: newStock}, {merge: true});
    tx.set(couponRef, {
      userId: uid,
      userName: u.name || (request.auth.token && request.auth.token.name) || "회원",
      drinkId,
      drinkName: DRINK_NAMES[drinkId],
      issuedAt: admin.firestore.FieldValue.serverTimestamp(),
      used: false,
    });
    tx.set(userRef, {
      rewardUnits: claimed + 1,
      rewardStreakSnapshot: streak,
    }, {merge: true});
  });

  return {couponId: couponRef.id, drinkId, drinkName: DRINK_NAMES[drinkId]};
});

// ── 앱 초기화: 내 서버 데이터 전체 삭제 ──────────────────────────
// 로그아웃 전에 호출. 보고서·쿠폰·출석 체크인·RSVP·그룹 멤버십·프로필/설정을
// 모두 삭제한다. (체크인/쿠폰은 클라이언트가 지울 수 없으므로 서버에서 처리)
exports.resetMyAccount = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");

  // 1) 내가 쓴 보고서 삭제(하위 포함).
  const reports = await db.collection("reports")
      .where("authorId", "==", uid).get();
  await Promise.all(reports.docs.map((d) => db.recursiveDelete(d.ref)));

  // 2) 내 쿠폰 삭제.
  const coupons = await db.collection("coupons")
      .where("userId", "==", uid).get();
  await Promise.all(coupons.docs.map((d) => d.ref.delete()));

  // 3) 전역 출석 기록 삭제.
  await db.recursiveDelete(db.collection("attendance").doc(uid));

  // 4) 모든 그룹에서 멤버십 + 출석 체크인/RSVP 삭제.
  const groups = await db.collection("groups").get();
  await Promise.all(groups.docs.flatMap((g) => {
    const gref = db.collection("groups").doc(g.id);
    return [
      gref.collection("members").doc(uid).delete().catch(() => {}),
      db.recursiveDelete(gref.collection("attendance").doc(uid)),
    ];
  }));

  // 5) 사용자 문서(프로필/설정/리워드/토큰/그룹) 삭제.
  await db.recursiveDelete(db.collection("users").doc(uid));

  logger.info("account reset", {uid});
  return {ok: true};
});

// ══ 관리자: 멤버 계정(아이디) 조회 + 비밀번호 재설정 ══════════════

/** 관리자: 그룹 멤버들의 로그인 이메일(아이디)을 조회. */
exports.getGroupMemberAccounts = onCall(async (request) => {
  await assertAdmin(request);
  const gid = request.data && request.data.gid;
  if (!gid) throw new HttpsError("invalid-argument", "그룹이 필요합니다.");
  const members = await db.collection("groups").doc(gid)
      .collection("members").get();
  const entries = members.docs.map((m) => ({
    uid: m.id, name: (m.data().name) || "회원",
  }));
  if (entries.length === 0) return {members: []};
  // Auth 에서 이메일 조회(최대 100명씩).
  const ident = entries.map((e) => ({uid: e.uid}));
  const result = await admin.auth().getUsers(ident);
  const emailByUid = {};
  for (const u of result.users) emailByUid[u.uid] = u.email || "";
  return {
    members: entries.map((e) => ({
      uid: e.uid, name: e.name, email: emailByUid[e.uid] || "",
    })),
  };
});

/** 관리자: 멤버의 임시 비밀번호를 발급(재설정). 원문을 반환해 전달용으로 사용. */
exports.resetMemberPassword = onCall(async (request) => {
  await assertAdmin(request);
  const targetUid = request.data && request.data.uid;
  if (!targetUid) throw new HttpsError("invalid-argument", "대상이 필요합니다.");
  // 읽기 쉬운 임시 비밀번호 생성(혼동 문자 제외).
  const chars = "abcdefghjkmnpqrstuvwxyz23456789";
  let pw = "yh";
  for (let i = 0; i < 6; i++) {
    // Math.random 사용 가능(함수 런타임).
    pw += chars[Math.floor(Math.random() * chars.length)];
  }
  await admin.auth().updateUser(targetUid, {password: pw});
  let email = "";
  try {
    const u = await admin.auth().getUser(targetUid);
    email = u.email || "";
  } catch (_) {}
  logger.info("member password reset", {targetUid});
  return {password: pw, email};
});

// ── 쿠폰 사용 처리(직원 코드 검증) ──
exports.redeemCoupon = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const {couponId, code} = request.data || {};
  if (!couponId || !code) {
    throw new HttpsError("invalid-argument", "쿠폰/코드가 필요합니다.");
  }
  const cfgSnap = await db.collection("config").doc("rewards").get();
  const cfgCode = (cfgSnap.data() || {}).code || "";
  if (!cfgCode || String(cfgCode) !== String(code).trim()) {
    return {ok: false, reason: "bad_code"};
  }
  const ref = db.collection("coupons").doc(couponId);
  const snap = await ref.get();
  if (!snap.exists) return {ok: false, reason: "not_found"};
  if (snap.data().used === true) return {ok: true, already: true};
  await ref.set({
    used: true,
    usedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {ok: true};
});
