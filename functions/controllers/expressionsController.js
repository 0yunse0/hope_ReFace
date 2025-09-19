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

// 점수 데이터 정규화
function normalizeScores(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const allowed = ['neutral', 'smile', 'angry', 'sad'];
  const clean = {};
  for (const k of allowed) {
    const v = raw[k];
    if (typeof v === 'number' && Number.isFinite(v)) clean[k] = v;
  }
  return Object.keys(clean).length ? clean : null;
}

/** 초기 표정 점수 저장 */
async function saveInitialScores(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const scoresIn = normalizeScores(req.body?.expressionScores);
    if (!scoresIn) {
      return res.status(400).json({ error: 'bad_request', detail: 'expressionScores required' });
    }

    const userRef = db.collection('users').doc(uid);
    const dateKey = makeDateKey('Asia/Seoul');
    const batch = db.batch();

    // 1) 점수 문서
    const scoresRef = userRef.collection('initialExpressions').doc('scores');
    batch.set(
      scoresRef,
      {
        expressionScores: scoresIn,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // 2) 각 표정별 초기 세션 미러링
    for (const [expr, sc] of Object.entries(scoresIn)) {
      const sid = `initial_${expr}`;
      const sessRef = userRef.collection('trainingSessions').doc(sid);
      const now = admin.firestore.FieldValue.serverTimestamp();
      batch.set(
        sessRef,
        {
          expr,
          finalScore: sc,
          status: 'completed',
          isInitial: true,
          dateKey,
          startedAt: now,
          completedAt: now,
        },
        { merge: true }
      );
    }

    await batch.commit();

    return res.json({ ok: true, dateKey, expressionScores: scoresIn });
  } catch (e) {
    console.error('[saveInitialScores] error', e);
    return res.status(500).json({ error: 'server_error' });
  }
}

/** 초기 표정 점수 조회 */
async function getInitialScores(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const doc = await db
      .collection('users').doc(uid)
      .collection('initialExpressions').doc('scores')
      .get();

    if (!doc.exists) {
      return res.json({ expressionScores: null, updatedAt: null });
    }

    const data = doc.data() || {};
    const updatedAtISO = data.updatedAt?.toDate ? data.updatedAt.toDate().toISOString() : null;

    return res.json({
      expressionScores: data.expressionScores ?? null,
      updatedAt: updatedAtISO,
    });
  } catch (e) {
    console.error('[getInitialScores] error', e);
    return res.status(500).json({ error: 'server_error' });
  }
}

module.exports = {
  saveInitialScores,
  getInitialScores,
};
