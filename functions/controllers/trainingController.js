// functions/controllers/trainingController.js
'use strict';

const admin = require('firebase-admin');
const db = admin.firestore();
const {
  landmarkProgress,
  aggregateProgress,
  symmetry
} = require('../utils/landmarkMetrics');

// -------------------- 유틸 --------------------
function pickOr(arr, idx, fallback) {
  return (Array.isArray(arr) && idx >= 0 && idx < arr.length && typeof arr[idx] === 'number') ?
    arr[idx] :
    fallback;
}

function avgPoints(points) {
  let sx = 0; let sy = 0; let sz = 0; let c = 0; let hasZ = false;
  for (const p of points) {
    if (p && typeof p.x === 'number' && typeof p.y === 'number') {
      sx += p.x; sy += p.y; c++;
      if (typeof p.z === 'number') {
        sz += p.z; hasZ = true;
      }
    }
  }
  if (c === 0) return null;
  const out = { x: sx / c, y: sy / c };
  if (hasZ) out.z = sz / c;
  return out;
}

function averageCurrentFromFrames(frames) {
  const bucket = {};
  for (const f of frames) {
    const cur = f && f.current;
    if (!cur || typeof cur !== 'object') continue;
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

function pickLastFrame(frames) {
  let last = null;
  for (const f of frames) {
    if (!last) last = f;
    else {
      const t1 = (last && typeof last.ts === 'number') ? last.ts : -Infinity;
      const t2 = (f && typeof f.ts === 'number') ? f.ts : -Infinity;
      if (t2 >= t1) last = f;
    }
  }
  return last || (Array.isArray(frames) ? frames[frames.length - 1] : null);
}

async function saveImageBase64ToBucket(uid, sid, setId, dataUrl) {
  if (!dataUrl || typeof dataUrl !== 'string') return null;
  const m = dataUrl.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/);
  if (!m) return null;

  const contentType = m[1];
  const base64Data = m[2];
  const buffer = Buffer.from(base64Data, 'base64');

  const bucket = admin.storage().bucket();
  const filePath = `users/${uid}/trainingSessions/${sid}/sets/${setId}/lastFrame.jpg`;
  const file = bucket.file(filePath);

  await file.save(buffer, {
    resumable: false,
    metadata: { contentType, cacheControl: 'public,max-age=31536000' },
  });

  await file.makePublic();
  return `https://storage.googleapis.com/${bucket.name}/${filePath}`;
}

// -------------------- 컨트롤러 --------------------
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

    const li = ids.indexOf('48');
    const ri = ids.indexOf('54');
    const sym = symmetry(
      pickOr(scores, li, setScore),
      pickOr(scores, ri, setScore)
    );

    return res.json({ progress: setScore * 100, symmetry: sym, raw: scores });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'progress calc failed' });
  }
}

async function startSession(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const expr = (req.body && req.body.expr) || null;
    const ref = db.collection('users').doc(uid).collection('trainingSessions').doc();
    await ref.set({
      expr,
      status: 'active',
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return res.json({ sid: ref.id });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'session start failed' });
  }
}

async function saveSet(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const sid = req.params.sid;
    const body = req.body || {};
    const baseline = body.baseline || {};
    const reference = body.reference || {};
    const frames = Array.isArray(body.frames) ? body.frames : [];
    const weights = body.weights;

    if (frames.length < 1) {
      return res.status(400).json({ error: 'frames must be a non-empty array' });
    }
    if (frames.length < 15) {
      return res.status(400).json({ error: 'need 15 frames (1 fps for 15s)' });
    }

    const avgCurrent = averageCurrentFromFrames(frames);

    const ids = Object.keys(avgCurrent);
    const eps = 1e-3;
    const scores = ids.map((id) =>
      landmarkProgress(baseline[id], reference[id], avgCurrent[id], eps)
    );
    const setScore = aggregateProgress(scores, weights);

    const li = ids.indexOf('48');
    const ri = ids.indexOf('54');
    const sym = symmetry(
      pickOr(scores, li, setScore),
      pickOr(scores, ri, setScore)
    );

    const setsRef = db.collection('users').doc(uid)
      .collection('trainingSessions').doc(sid)
      .collection('sets').doc();

    const last = pickLastFrame(frames);
    let lastFrameImage = null;
    try {
      if (last && last.imageBase64) {
        lastFrameImage = await saveImageBase64ToBucket(uid, sid, setsRef.id, last.imageBase64);
      }
    } catch (imgErr) {
      console.warn('[saveSet] image save failed:', imgErr?.message || imgErr);
    }

    await setsRef.set({
      avgCapture: avgCurrent,
      score: setScore * 100,
      symmetry: sym,
      framesCount: frames.length,
      lastFrameImage,
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
    return res.status(500).json({ error: 'set save failed' });
  }
}

async function finalizeSession(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const sid = req.params.sid;
    const ref = db.collection('users').doc(uid).collection('trainingSessions').doc(sid);

    const setsSnap = await ref.collection('sets').get();
    const scores = [];
    setsSnap.forEach((d) => {
      const sc = (d.data() && typeof d.data().score === 'number') ? d.data().score : null;
      if (typeof sc === 'number') scores.push(sc);
    });
    const dayScore = scores.length ? (scores.reduce((a, b) => a + b, 0) / scores.length) : 0;

    const summary = (req.body && Object.prototype.hasOwnProperty.call(req.body, 'summary')) ?
      req.body.summary :
      null;

    await ref.set({
      finalScore: dayScore,
      summary,
      status: 'completed',
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return res.json({ ok: true, finalScore: dayScore, setsCount: scores.length });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'session finalize failed' });
  }
}

async function listSessions(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const snap = await db.collection('users').doc(uid)
      .collection('trainingSessions')
      .orderBy('startedAt', 'desc')
      .limit(50)
      .get();

    return res.json({
      sessions: snap.docs.map((d) => ({ id: d.id, ...d.data() }))
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'list sessions failed' });
  }
}

async function getSession(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const sid = req.params.sid;
    const ref = db.collection('users').doc(uid).collection('trainingSessions').doc(sid);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ error: 'not found' });

    const setsSnap = await ref.collection('sets').orderBy('createdAt').get();
    const sets = setsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

    return res.json({ session: { id: doc.id, ...doc.data(), sets } });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'get session failed' });
  }
}

// -------------------- 추천 (진척도 낮은 순) --------------------
async function getRecommendations(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const raw = parseInt(req.query.limit, 10);
    const limit = isNaN(raw) ? 3 : Math.min(10, Math.max(1, raw));

    const exprs = ['neutral', 'smile', 'angry', 'sad'];
    const candidates = [];

    for (const expr of exprs) {
      const snap = await db
        .collection('users').doc(uid)
        .collection('trainingSessions')
        .where('expr', '==', expr)
        .where('status', '==', 'completed')
        .orderBy('completedAt', 'desc')
        .limit(50)
        .get();

      if (snap.empty) {
        candidates.push({
          expr,
          avgScore: null,
          sessionsCount: 0,
          lastSessionAt: null,
        });
        continue;
      }

      let sum = 0; let cnt = 0; let last = null;
      snap.forEach((doc) => {
        const d = doc.data();
        const sc = (typeof d.finalScore === 'number') ? d.finalScore : null;
        if (sc != null) {
          sum += sc; cnt += 1;
        }
        const ts = d.completedAt?.toDate?.() ?? (d.completedAt ? new Date(d.completedAt) : null);
        if (!last || (ts && ts > last)) last = ts;
      });

      const avg = cnt > 0 ? +(sum / cnt).toFixed(2) : null;
      candidates.push({
        expr,
        avgScore: avg,
        sessionsCount: cnt,
        lastSessionAt: last ? last.toISOString() : null,
      });
    }

    const sorted = candidates.slice().sort((a, b) => {
      const av = a.avgScore == null ? 0 : a.avgScore;
      const bv = b.avgScore == null ? 0 : b.avgScore;
      return av - bv;
    });

    const recommendedExpr = (sorted[0]?.expr) || 'neutral';

    return res.json({
      recommendedExpr,
      reason: '최근 평균 진척도가 가장 낮음',
      candidates: sorted.slice(0, limit),
    });
  } catch (err) {
    console.error('getRecommendations error', err);
    return res.status(500).json({ error: 'server_error' });
  }
}

// -------------------- exports --------------------
module.exports = {
  calcProgress,
  startSession,
  saveSet,
  finalizeSession,
  listSessions,
  getSession,
  getRecommendations, // ★ 추가
};
