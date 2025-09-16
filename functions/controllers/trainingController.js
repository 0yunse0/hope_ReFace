'use strict';

const admin = require('firebase-admin');
const db = admin.firestore();


// Firestore Timestamp → ISO8601 문자열
function toISODate(ts) {
  try {
    if (!ts) return null;
    if (typeof ts.toDate === 'function') return ts.toDate().toISOString();
    if (ts._seconds != null) {
      const nanos = ts._nanoseconds ?? ts._nanos ?? 0;
      return new Date(ts._seconds * 1000 + Math.floor(nanos / 1e6)).toISOString();
    }
    const d = new Date(ts);
    return isNaN(d) ? null : d.toISOString();
  } catch {
    return null;
  }
}

// YYYY-MM-DD(KST)
function makeDateKey(tz = 'Asia/Seoul') {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date());
  const y = parts.find((p) => p.type === 'year')?.value;
  const m = parts.find((p) => p.type === 'month')?.value;
  const d = parts.find((p) => p.type === 'day')?.value;
  return `${y}-${m}-${d}`;
}


/** 세션 시작: { expr } */
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
    console.error('[startSession] error', e);
    return res.status(500).json({ error: 'session start failed' });
  }
}

/** 세션 완료: { finalScore, summary? } */
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
    console.error('[finalizeSession] error', e);
    return res.status(500).json({ error: 'session finalize failed' });
  }
}

/**
 * 세션 목록
 * - 쿼리: ?expr=smile (선택), ?limit=100 (선택; 기본 50, 최대 200)
 * - 응답: 표준화된 필드(sid, expr, dateKey, finalScore, status, isInitial, startedAt, completedAt)
 */
async function listSessions(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const expr = (req.query.expr || '').trim();
    let limit = parseInt(req.query.limit, 10);
    if (!Number.isFinite(limit) || limit <= 0) limit = 50;
    if (limit > 200) limit = 200;

    let q = db.collection('users').doc(uid).collection('trainingSessions');

    // ① 필터 먼저
    if (expr) q = q.where('expr', '==', expr);

    // ② 정렬/제한
    q = q.orderBy('startedAt', 'desc').limit(limit);

    const snap = await q.get();

    const sessions = snap.docs.map((d) => {
      const data = d.data() || {};
      return {
        sid: d.id,
        expr: data.expr ?? null,
        dateKey: data.dateKey ?? null,
        status: data.status ?? null,
        isInitial: !!data.isInitial,
        finalScore: typeof data.finalScore === 'number' ? data.finalScore : null,
        summary: data.summary ?? null,
        startedAt: toISODate(data.startedAt),
        completedAt: toISODate(data.completedAt),
      };
    });

    return res.json({ sessions });
  } catch (e) {
    console.error('[listSessions] error', e);
    return res.status(500).json({ error: 'list sessions failed' });
  }
}

async function getSession(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const sid = req.params.sid;
    const doc = await db.collection('users').doc(uid)
      .collection('trainingSessions').doc(sid).get();

    if (!doc.exists) return res.status(404).json({ error: 'not_found' });

    const data = doc.data() || {};
    const session = {
      sid: doc.id,
      expr: data.expr ?? null,
      dateKey: data.dateKey ?? null,
      status: data.status ?? null,
      isInitial: !!data.isInitial,
      finalScore: typeof data.finalScore === 'number' ? data.finalScore : null,
      summary: data.summary ?? null,
      startedAt: toISODate(data.startedAt),
      completedAt: toISODate(data.completedAt),
    };

    return res.json({ session });
  } catch (e) {
    console.error('[getSession] error', e);
    return res.status(500).json({ error: 'get session failed' });
  }
}

module.exports = {
  startSession,
  finalizeSession,
  listSessions,
  getSession,
};
