'use strict';

const admin = require('firebase-admin');
const db = admin.firestore();

const VALID = new Set(['neutral', 'smile', 'angry', 'sad']);

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

/**
 * 초기 표정 점수 저장
 * body: {
 *   "expressionScores": {
 *     "neutral": 30,
 *     "smile": 20,
 *     "angry": 10,
 *     "sad": 50
 *   }
 * }
 * - 날짜는 서버 기준(Asia/Seoul)으로 dateKey("YYYY-MM-DD") 생성
 * - 저장 위치: users/{uid}/expressionScores/{dateKey}
 */
async function saveInitialExpressionScores(req, res) {
  try {
    const uid = req.uid || req.user?.uid;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    const scores = req.body?.expressionScores;
    if (!scores || typeof scores !== 'object') {
      return res.status(400).json({ error: 'bad_request', detail: 'expressionScores object required' });
    }

    for (const [k, v] of Object.entries(scores)) {
      if (!VALID.has(k)) {
        return res.status(400).json({ error: 'bad_request', detail: `invalid key: ${k}` });
      }
      if (typeof v !== 'number' || Number.isNaN(v)) {
        return res.status(400).json({ error: 'bad_request', detail: `score must be number: ${k}` });
      }
    }

    const dateKey = makeDateKey('Asia/Seoul');

    await db.collection('users').doc(uid)
      .collection('expressionScores').doc(dateKey)
      .set({
        expressionScores: scores,
        dateKey,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

    await db.collection('users').doc(uid)
      .collection('expressionScores').doc('latest')
      .set({
        expressionScores: scores,
        dateKey,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

    return res.json({ ok: true, dateKey });
  } catch (e) {
    console.error('SAVE_INITIAL_EXPRESSION_SCORES_ERR', e);
    return res.status(500).json({ error: 'server_error' });
  }
}

module.exports = {
  saveInitialExpressionScores,
};
