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

/**
 * 무차별 대입 방어: 계정별 실패 시도를 rate_limits/{key} 에 기록하고,
 * 창(windowMs) 안에서 maxFails 회 넘게 실패하면 잠근다(cooldownMs).
 * 코드 검증 함수(verifyJoinCode·redeemCoupon)에서 호출.
 */
async function assertNotThrottled(key, {maxFails, windowMs, cooldownMs}) {
  const ref = db.collection("rate_limits").doc(key);
  const now = Date.now();
  const snap = await ref.get();
  const d = snap.exists ? snap.data() : {};
  if (d.lockedUntil && d.lockedUntil > now) {
    throw new HttpsError("resource-exhausted", "too_many_attempts",
        {reason: "too_many_attempts",
          retryAfter: Math.ceil((d.lockedUntil - now) / 1000)});
  }
  // 창이 지났으면 카운터 리셋.
  const windowStart = d.windowStart && (now - d.windowStart) < windowMs
    ? d.windowStart : now;
  return {ref, now, windowStart, fails: (d.windowStart === windowStart)
    ? (d.fails || 0) : 0, maxFails, cooldownMs};
}

/** 시도 실패 기록(+1). 임계 초과 시 잠금 설정. */
async function recordFailure(ctx) {
  const {ref, now, windowStart, fails, maxFails, cooldownMs} = ctx;
  const next = fails + 1;
  const payload = {windowStart, fails: next, updatedAt: now};
  if (next >= maxFails) payload.lockedUntil = now + cooldownMs;
  await ref.set(payload, {merge: true});
}

/** 시도 성공 → 카운터 초기화. */
async function clearFailures(ctx) {
  await ctx.ref.set(
      {windowStart: 0, fails: 0, lockedUntil: 0, updatedAt: ctx.now},
      {merge: true});
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

// ══ 리워드(빽다방 쿠폰) — 서버에서 발급 규칙/재고 검증 ══════════════
//
// 발급 규칙(출석과 무관):
//  1) 하루(KST) 1개만 발급 가능.
//  2) 사용하지 않은 쿠폰이 있으면 새로 발급 불가.
//  3) 재고가 있어야 발급(발급 시점에 차감).

const DRINK_NAMES = {
  peachtea: "제로슈거 납작복숭아 아이스티",
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

// ── 쿠폰 발급(일일 1개 + 미사용 쿠폰 없음 + 재고 차감, 원자적) ──
// ── 가입코드 인증 ────────────────────────────────────────────────
// 회원가입 시 학과 가입코드를 검증하고, 위조할 수 없는 인증 마크
// (members_verified/{uid}, 규칙상 클라이언트 쓰기 금지)를 남긴다.
// 리워드 발급이 이 마크를 요구하므로 코드 없이 계정만 만든 외부인은
// 리워드를 쓸 수 없다.
exports.verifyJoinCode = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const code = String((request.data && request.data.code) || "").trim();
  if (!code) throw new HttpsError("invalid-argument", "가입코드가 필요합니다.");
  // 계정당 10분에 5회 실패 → 30분 잠금(가입코드 전수조사 차단).
  const ctx = await assertNotThrottled(`joincode_${uid}`,
      {maxFails: 5, windowMs: 10 * 60 * 1000, cooldownMs: 30 * 60 * 1000});
  const snap = await db.collection("secrets").doc("join_code").get();
  const expected = String((snap.data() || {}).code || "").trim();
  if (!expected) {
    throw new HttpsError("failed-precondition", "join_code_not_set",
        {reason: "join_code_not_set"});
  }
  if (code !== expected) {
    await recordFailure(ctx);
    throw new HttpsError("permission-denied", "bad_join_code",
        {reason: "bad_join_code"});
  }
  await clearFailures(ctx);
  await db.collection("members_verified").doc(uid).set({
    via: "code",
    verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {ok: true};
});

// 가입코드 제도 도입 시점. 이전에 만들어진 계정(기존 회원)은 자동 인정.
const JOIN_CODE_CUTOFF = Date.parse("2026-09-16T15:00:00Z");

/** 리워드 발급 자격: 인증 마크 보유, 또는 제도 도입 전 가입한 기존 회원. */
async function assertVerifiedMember(uid) {
  const ref = db.collection("members_verified").doc(uid);
  const snap = await ref.get();
  if (snap.exists) return;
  const rec = await admin.auth().getUser(uid);
  const created = Date.parse(rec.metadata.creationTime);
  if (created < JOIN_CODE_CUTOFF) {
    // 기존 회원: 무중단으로 자동 인정하고 마크를 남긴다.
    await ref.set({
      via: "grandfathered",
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return;
  }
  throw new HttpsError("permission-denied", "join_code_required",
      {reason: "join_code_required"});
}

exports.claimCoupon = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const drinkId = request.data && request.data.drinkId;
  if (!DRINK_NAMES[drinkId]) {
    throw new HttpsError("invalid-argument", "잘못된 음료입니다.");
  }
  // 학과 가입코드로 인증된 회원(또는 기존 회원)만 발급.
  await assertVerifiedMember(uid);

  const userRef = db.collection("users").doc(uid);
  const cfgRef = db.collection("config").doc("rewards");
  const couponRef = db.collection("coupons").doc();

  await db.runTransaction(async (tx) => {
    const [mineSnap, userSnap, cfgSnap] = await Promise.all([
      tx.get(db.collection("coupons").where("userId", "==", uid)),
      tx.get(userRef),
      tx.get(cfgRef),
    ]);

    const todayKey = dayKey(new Date());
    for (const doc of mineSnap.docs) {
      const c = doc.data() || {};
      if (c.used !== true) {
        throw new HttpsError(
            "failed-precondition", "unused_coupon",
            {reason: "unused_coupon"});
      }
      const issuedKey = c.issuedAt ? dayKey(c.issuedAt.toDate()) : null;
      if (issuedKey === todayKey) {
        throw new HttpsError(
            "failed-precondition", "daily_limit",
            {reason: "daily_limit"});
      }
    }

    const cfg = cfgSnap.data() || {};
    const stock = cfg.stock || {};
    const remaining = typeof stock[drinkId] === "number" ? stock[drinkId] : 0;
    if (remaining <= 0) {
      throw new HttpsError("resource-exhausted", "해당 음료 재고가 소진됐습니다.");
    }
    // 재고는 쿠폰을 '받는(발급)' 시점에 차감한다.
    const newStock = Object.assign({}, stock);
    newStock[drinkId] = remaining - 1;
    // 수령자 이름은 위조 방지를 위해 서버가 관리하는 값만 쓴다.
    // (users/{uid}.name 은 사용자가 자유롭게 바꿀 수 있어 명단이 오염됨)
    // 우선순위: Auth displayName(토큰) → Auth 레코드 → '회원'.
    let verifiedName = (request.auth.token && request.auth.token.name) || "";
    if (!verifiedName) {
      try {
        const rec = await admin.auth().getUser(uid);
        verifiedName = rec.displayName || "";
      } catch (_) {}
    }
    tx.set(cfgRef, {stock: newStock}, {merge: true});
    tx.set(couponRef, {
      userId: uid,
      userName: verifiedName || "회원",
      drinkId,
      drinkName: DRINK_NAMES[drinkId],
      issuedAt: admin.firestore.FieldValue.serverTimestamp(),
      used: false,
    });
  });

  return {couponId: couponRef.id, drinkId, drinkName: DRINK_NAMES[drinkId]};
});

// ── 계정 초기화: 한 회원의 서버 데이터 전체 삭제 ──────────────────
// 보고서·쿠폰·출석 체크인·RSVP·그룹 멤버십·프로필/설정을 모두 삭제한다.
// (체크인/쿠폰은 클라이언트가 지울 수 없으므로 서버에서 처리)
//
// 관리자 전용이다. 예전에는 회원이 스스로 호출하는 resetMyAccount 였는데,
// 실수로 전체 기록을 날리는 사고가 나서 관리자만 수행하도록 바꿨다.
// UI 에서 감추는 것만으로는 SDK 직접 호출을 막을 수 없어 함수를 교체했다.
const resetAccountData = async (uid) => {
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
};

exports.resetMemberAccount = onCall(async (request) => {
  await assertAdmin(request);
  const uid = request.data && request.data.uid;
  if (!uid) throw new HttpsError("invalid-argument", "회원이 필요합니다.");
  await resetAccountData(uid);
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
  // 다음 로그인 때 새 비밀번호 설정을 유도하는 마크(앱이 확인 후 해제).
  await db.collection("users").doc(targetUid)
      .set({mustChangePassword: true}, {merge: true});
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
  const {couponId, code, signature, receipt} = request.data || {};
  if (!couponId || !code) {
    throw new HttpsError("invalid-argument", "쿠폰/코드가 필요합니다.");
  }
  // 수령 증빙 필수: 수령자 전자서명(PNG) + 주문서/영수증 사진(JPEG).
  if (!signature || !receipt) {
    throw new HttpsError("invalid-argument", "서명과 영수증 사진이 필요합니다.");
  }
  // Firestore 문서 1MB 한도 보호(base64 기준 대략 상한).
  if (String(signature).length > 300000 || String(receipt).length > 500000) {
    throw new HttpsError("invalid-argument", "증빙 이미지가 너무 큽니다.");
  }
  // 계정당 10분에 5회 실패 → 30분 잠금(직원 4자리 코드 전수조사 차단).
  const ctx = await assertNotThrottled(`redeem_${uid}`,
      {maxFails: 5, windowMs: 10 * 60 * 1000, cooldownMs: 30 * 60 * 1000});
  // 직원 확인 코드는 secrets/rewards_code(관리자만 읽기)에 둔다.
  // 예전에는 config/rewards.code 에 있어 로그인한 누구나 읽을 수 있었다 →
  // 남아 있으면 새 위치로 옮기고 노출 위치에서 지운다(1회 자동 이관).
  let cfgCode = "";
  const secSnap = await db.collection("secrets").doc("rewards_code").get();
  cfgCode = String((secSnap.data() || {}).code || "");
  if (!cfgCode) {
    const legacy = await db.collection("config").doc("rewards").get();
    cfgCode = String((legacy.data() || {}).code || "");
    if (cfgCode) {
      await db.collection("secrets").doc("rewards_code").set({code: cfgCode});
      await db.collection("config").doc("rewards").set(
          {code: admin.firestore.FieldValue.delete()}, {merge: true});
    }
  }
  if (!cfgCode || cfgCode !== String(code).trim()) {
    await recordFailure(ctx);
    return {ok: false, reason: "bad_code"};
  }
  await clearFailures(ctx);
  const ref = db.collection("coupons").doc(couponId);
  const snap = await ref.get();
  if (!snap.exists) return {ok: false, reason: "not_found"};
  if (snap.data().used === true) return {ok: true, already: true};
  await ref.set({
    used: true,
    usedAt: admin.firestore.FieldValue.serverTimestamp(),
    signatureB64: String(signature),
    receiptB64: String(receipt),
  }, {merge: true});
  return {ok: true};
});
