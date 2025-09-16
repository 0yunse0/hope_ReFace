'use strict';

const admin = require('firebase-admin');
const db = admin.firestore();

// YYYY-MM-DD (KST)
function makeDateKey(tz = 'Asia/Seoul') {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date());
  const y = parts.find((p) => p.type === 'year')?.value;
  const m = parts.find((p) => p.type === 'month')?.value;
  const d = parts.find((p) => p.type === 'day')?.value;
  return `${y}-${m}-${d}`;
}

/** 초기 표정 '점수' 저장 + 세션에도 1건씩 미러링 */
async function saveInitialScores(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const scores = req.body?.expressionScores;
    if (!scores || typeof scores !== 'object') {
      return res.status(400).json({ error: 'bad_request', detail: 'expressionScores required' });
    }

    const allowed = ['neutral', 'smile', 'angry', 'sad'];
    const clean = {};
    for (const k of allowed) {
      const v = scores[k];
      if (typeof v === 'number' && !Number.isNaN(v)) clean[k] = v;
    }
    if (Object.keys(clean).length === 0) {
      return res.status(400).json({ error: 'bad_request', detail: 'no valid scores' });
    }

    const userRef = db.collection('users').doc(uid);
    const dateKey = makeDateKey('Asia/Seoul');
    const batch = db.batch();

    // 1) 초기 점수 문서
    const scoresRef = userRef.collection('initialExpressions').doc('scores');
    batch.set(
      scoresRef,
      { ...clean, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );

    // 2) 각 표정별 초기 세션 미러링
    for (const [expr, sc] of Object.entries(clean)) {
      const sid = `initial_${expr}`;
      const sessRef = userRef.collection('trainingSessions').doc(sid);
      batch.set(
        sessRef,
        {
          expr,
          finalScore: sc,
          status: 'completed',
          isInitial: true,
          dateKey,
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }

    await batch.commit();
    return res.json({ ok: true, dateKey });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'server_error' });
  }
}

/** 초기 표정 '점수' 조회 */
async function getInitialScores(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const doc = await db
      .collection('users').doc(uid)
      .collection('initialExpressions').doc('scores')
      .get();

    if (!doc.exists) return res.json({ scores: null, updatedAt: null });

    const data = doc.data() || {};
    const updatedAtISO = data.updatedAt?.toDate ? data.updatedAt.toDate().toISOString() : null;

    const scores = {};
    for (const k of ['neutral', 'smile', 'angry', 'sad']) {
      if (typeof data[k] === 'number') scores[k] = data[k];
    }

    return res.json({ scores, updatedAt: updatedAtISO });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'server_error' });
  }
}

module.exports = {
  saveInitialScores,
  getInitialScores,
};
