'use strict';

const admin = require('firebase-admin');
const db = admin.firestore();

/** ISO8601 문자열 변환 */
function toISODate(ts) {
  if (!ts) return null;
  if (typeof ts.toDate === 'function') {
    return ts.toDate().toISOString();
  }
  if (typeof ts._seconds === 'number') {
    return new Date(ts._seconds * 1000).toISOString();
  }
  return null;
}

/** 날짜키 (YYYY-MM-DD, Asia/Seoul) */
function makeDateKey(tz = 'Asia/Seoul') {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());
  const y = parts.find((p) => p.type === 'year')?.value;
  const m = parts.find((p) => p.type === 'month')?.value;
  const d = parts.find((p) => p.type === 'day')?.value;
  return `${y}-${m}-${d}`;
}

/** 세션 시작 */
async function startSession(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const expr = req.body?.expr ?? null;
    if (typeof expr !== 'string' || !expr) {
      return res.status(400).json({ error: 'bad_request', detail: 'expr required' });
    }

    const dateKey = makeDateKey('Asia/Seoul');
    const ref = db.collection('users').doc(uid).collection('trainingSessions').doc();

    await ref.set({
      expr,
      status: 'active',
      dateKey,
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.json({ sid: ref.id, dateKey });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'session start failed' });
  }
}

/** 세션 완료 */
async function finalizeSession(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const sid = req.params.sid;
    const { finalScore, summary } = req.body || {};

    if (typeof finalScore !== 'number' || Number.isNaN(finalScore)) {
      return res.status(400).json({ error: 'bad_request', detail: 'finalScore must be a number' });
    }

    const dateKey = makeDateKey('Asia/Seoul');
    const ref = db.collection('users').doc(uid).collection('trainingSessions').doc(sid);

    await ref.set({
      finalScore,
      summary: summary ?? null,
      status: 'completed',
      dateKey,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return res.json({ ok: true, finalScore, dateKey });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'session finalize failed' });
  }
}

/** 세션 목록 */
async function listSessions(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const { expr } = req.query;

    let query = db.collection('users').doc(uid)
      .collection('trainingSessions')
      .orderBy('startedAt', 'desc')
      .limit(50);

    if (expr) {
      query = query.where('expr', '==', expr);
    }

    const snap = await query.get();
    return res.json({
      sessions: snap.docs.map((d) => {
        const data = d.data();
        return {
          sid: d.id,
          expr: data.expr,
          dateKey: data.dateKey,
          status: data.status,
          finalScore: data.finalScore ?? null,
          summary: data.summary ?? null,
          startedAt: toISODate(data.startedAt),
          completedAt: toISODate(data.completedAt),
        };
      }),
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'list sessions failed' });
  }
}

/** 세션 상세 */
async function getSession(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const sid = req.params.sid;
    const doc = await db.collection('users').doc(uid)
      .collection('trainingSessions').doc(sid).get();

    if (!doc.exists) return res.status(404).json({ error: 'not_found' });

    const data = doc.data();
    return res.json({
      session: {
        sid: doc.id,
        expr: data.expr,
        dateKey: data.dateKey,
        status: data.status,
        finalScore: data.finalScore ?? null,
        summary: data.summary ?? null,
        startedAt: toISODate(data.startedAt),
        completedAt: toISODate(data.completedAt),
      },
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'get session failed' });
  }
}

module.exports = {
  startSession,
  finalizeSession,
  listSessions,
  getSession,
};
