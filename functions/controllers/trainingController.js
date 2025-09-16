'use strict';

const admin = require('firebase-admin');
const db = admin.firestore();

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
      sessions: snap.docs.map((d) => ({ id: d.id, ...d.data() })),
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
    const doc = await db.collection('users').doc(uid)
      .collection('trainingSessions').doc(sid).get();

    if (!doc.exists) return res.status(404).json({ error: 'not found' });
    return res.json({ session: { id: doc.id, ...doc.data() } });
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
