const { admin, db } = require("../firebase");
const { landmarkProgress, aggregateProgress, symmetry } = require("../utils/landmarkMetrics");

// 배열 idx 안전 접근
function pickOr(arr, idx, fallback) {
  return (Array.isArray(arr) && idx >= 0 && idx < arr.length && typeof arr[idx] === "number") ?
    arr[idx] :
    fallback;
}

// 좌표 배열 평균: [{x,y,z?}, ...] -> { x̄, ȳ, z̄? }
function avgPoints(points) {
  let sx = 0; let sy = 0; let sz = 0; let c = 0; let hasZ = false;
  for (const p of points) {
    if (p && typeof p.x === "number" && typeof p.y === "number") {
      sx += p.x; sy += p.y; c++;
      if (typeof p.z === "number") {
        sz += p.z; hasZ = true;
      }
    }
  }
  if (c === 0) return null;
  const out = { x: sx / c, y: sy / c };
  if (hasZ) out.z = sz / c;
  return out;
}

// frames[*].current 들로 랜드마크별 평균 current 구성
function averageCurrentFromFrames(frames) {
  const bucket = {}; // { "48": [pt, pt, ...], ... }
  for (const f of frames) {
    const cur = f && f.current;
    if (!cur || typeof cur !== "object") continue;
    for (const id of Object.keys(cur)) {
      if (!bucket[id]) bucket[id] = [];
      bucket[id].push(cur[id]);
    }
  }
  const avgCurrent = {};
  for (const id of Object.keys(bucket)) {
    const m = avgPoints(bucket[id]);
    if (m) avgCurrent[id] = m;
  }
  return avgCurrent;
}

// 마지막 프레임(가장 큰 ts, 없으면 배열 마지막)
function pickLastFrame(frames) {
  let last = null;
  for (const f of frames) {
    if (!last) last = f;
    else {
      const t1 = (last && typeof last.ts === "number") ? last.ts : -Infinity;
      const t2 = (f && typeof f.ts === "number") ? f.ts : -Infinity;
      if (t2 >= t1) last = f;
    }
  }
  return last || (Array.isArray(frames) ? frames[frames.length - 1] : null);
}

// dataURL(base64) 이미지를 GCS에 저장(선택)
async function saveImageBase64ToBucket(uid, sid, setId, dataUrl) {
  if (!dataUrl || typeof dataUrl !== "string") return null;
  const m = dataUrl.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/);
  if (!m) return null;
  const contentType = m[1];
  const base64Data = m[2];
  const buffer = Buffer.from(base64Data, "base64");
  const bucket = admin.storage().bucket(); // 기본 버킷
  const filePath = `users/${uid}/trainingSessions/${sid}/sets/${setId}/lastFrame.jpg`;
  const file = bucket.file(filePath);
  await file.save(buffer, {
    resumable: false,
    metadata: { contentType, cacheControl: "public,max-age=31536000" },
  });
  return `gs://${bucket.name}/${filePath}`; // 필요하면 makePublic() 또는 Signed URL로 변경 가능
}

// ------ controllers ------

/**
 * 진행도 계산(단일 샷)
 * body: { baseline, reference, current, weights? }
 */
async function calcProgress(req, res) {
  try {
    const body = req.body || {};
    const baseline = body.baseline || {};
    const reference = body.reference || {};
    const current = body.current || {};
    const weights = body.weights;

    const ids = Object.keys(current);
    const eps = 1e-3;

    const scores = ids.map((id) =>
      landmarkProgress(baseline[id], reference[id], current[id], eps)
    );
    const setScore = aggregateProgress(scores, weights);

    const li = ids.indexOf("48");
    const ri = ids.indexOf("54");
    const sym = symmetry(
      pickOr(scores, li, setScore),
      pickOr(scores, ri, setScore)
    );

    return res.json({ progress: setScore * 100, symmetry: sym, raw: scores });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "progress calc failed" });
  }
}

/**
 * 세션 시작
 * body: { expr }
 */
async function startSession(req, res) {
  try {
    const uid = req.uid; // 통일
    const expr = (req.body && req.body.expr) || null;
    const ref = db.collection("users").doc(uid).collection("trainingSessions").doc();
    await ref.set({
      expr,
      status: "active",
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return res.json({ sid: ref.id });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "session start failed" });
  }
}

/**
 * 세트 저장 (15초 동안 1fps로 받은 frames 평균 + 마지막 프레임 사진 기록)
 * body: {
 *   baseline, reference,
 *   frames: [{ current: {...}, ts: 0..14, imageBase64? }, ...], // 15개 권장
 *   weights?
 * }
 */
async function saveSet(req, res) {
  try {
    const uid = req.uid; // 통일
    const sid = req.params.sid;
    const body = req.body || {};
    const baseline = body.baseline || {};
    const reference = body.reference || {};
    const frames = Array.isArray(body.frames) ? body.frames : [];
    const weights = body.weights;

    if (frames.length < 1) {
      return res.status(400).json({ error: "frames must be a non-empty array" });
    }
    if (frames.length < 15) {
      // 정확히 15개를 요구한다면 400, 유연하게 가려면 경고만 띄우고 진행해도 됨
      return res.status(400).json({ error: "need 15 frames (1 fps for 15s)" });
    }

    // 평균 current 생성
    const avgCurrent = averageCurrentFromFrames(frames);

    // 스코어 계산(평균 좌표 vs baseline/reference)
    const ids = Object.keys(avgCurrent);
    const eps = 1e-3;
    const scores = ids.map((id) =>
      landmarkProgress(baseline[id], reference[id], avgCurrent[id], eps)
    );
    const setScore = aggregateProgress(scores, weights);

    // 대칭(입꼬리 48/54)
    const li = ids.indexOf("48");
    const ri = ids.indexOf("54");
    const sym = symmetry(
      pickOr(scores, li, setScore),
      pickOr(scores, ri, setScore)
    );

    // 세트 문서 id를 먼저 확보
    const setsRef = db.collection("users").doc(uid)
      .collection("trainingSessions").doc(sid)
      .collection("sets").doc();

    // 마지막 프레임 이미지 저장(있으면)
    const last = pickLastFrame(frames);
    let lastFrameImage = null;
    try {
      if (last && last.imageBase64) {
        lastFrameImage = await saveImageBase64ToBucket(uid, sid, setsRef.id, last.imageBase64);
      }
    } catch (imgErr) {
      console.warn("[saveSet] image save failed:", imgErr && imgErr.message ? imgErr.message : imgErr);
    }

    await setsRef.set({
      avgCapture: avgCurrent,
      score: setScore * 100,
      symmetry: sym,
      framesCount: frames.length,
      lastFrameImage: lastFrameImage,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.json({
      setId: setsRef.id,
      score: setScore * 100,
      symmetry: sym,
      framesCount: frames.length,
      lastFrameImage,
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "set save failed" });
  }
}

/**
 * 세션 완료: 세트 점수 평균을 finalScore로 기록(그 날 값)
 * body: { summary? }  // finalScore는 서버가 세트 평균으로 계산
 */
async function finalizeSession(req, res) {
  try {
    const uid = req.uid; // 통일
    const sid = req.params.sid;

    const ref = db.collection("users").doc(uid).collection("trainingSessions").doc(sid);

    // 세트 점수 평균 계산
    const setsSnap = await ref.collection("sets").get();
    const scores = [];
    setsSnap.forEach((d) => {
      const sc = d.data() && typeof d.data().score === "number" ? d.data().score : null;
      if (typeof sc === "number") scores.push(sc);
    });
    const dayScore = scores.length ? (scores.reduce((a, b) => a + b, 0) / scores.length) : 0;

    const summary = (req.body && Object.prototype.hasOwnProperty.call(req.body, "summary")) ?
      req.body.summary : null;

    await ref.set({
      finalScore: dayScore, // 3세트 평균(세트 수가 달라도 평균)
      summary,
      status: "completed",
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return res.json({ ok: true, finalScore: dayScore, setsCount: scores.length });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "session finalize failed" });
  }
}

async function listSessions(req, res) {
  try {
    const uid = req.uid; // 통일
    const snap = await db.collection("users").doc(uid)
      .collection("trainingSessions")
      .orderBy("startedAt", "desc")
      .limit(50)
      .get();

    return res.json({ sessions: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "list sessions failed" });
  }
}

async function getSession(req, res) {
  try {
    const uid = req.uid; // 통일
    const sid = req.params.sid;
    const ref = db.collection("users").doc(uid).collection("trainingSessions").doc(sid);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ error: "not found" });

    const setsSnap = await ref.collection("sets").orderBy("createdAt").get();
    const sets = setsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

    return res.json({ session: { id: doc.id, ...doc.data(), sets } });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: "get session failed" });
  }
}

module.exports = {
  calcProgress,
  startSession,
  saveSet,
  finalizeSession,
  listSessions,
  getSession,
};
