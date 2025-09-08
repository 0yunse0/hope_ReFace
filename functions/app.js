const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

const app = express();

app.use(cors({ origin: true }));
app.use(express.json({ limit: '1mb' }));

// 헬스체크
app.get('/health', (req, res) => res.json({ ok: true }));

// 토큰 검증
const authGuard = async (req, res, next) => {
  try {
    const auth = req.headers.authorization || '';
    const m = auth.match(/^Bearer (.+)$/);
    if (!m) return res.status(401).json({ error: 'unauthorized', detail: 'Missing Bearer token' });
    const decoded = await admin.auth().verifyIdToken(m[1]);
    req.uid = decoded.uid;
    next();
  } catch (err) {
    res.status(401).json({ error: 'unauthorized', detail: String(err?.message || err) });
  }
};

// 초기 표정 저장
app.post('/expressions/initial', authGuard, async (req, res) => {
  try {
    const { expressions, smile, angry, sad, neutral } = req.body || {};
    const pack = expressions ?? { smile, angry, sad, neutral };

    const requiredExpr = ['smile', 'angry', 'sad', 'neutral'];
    const points = [
      'bottomMouth', 'rightMouth', 'leftMouth',
      'leftEye', 'rightEye', 'rightCheek', 'leftCheek', 'noseBase'
    ];

    for (const e of requiredExpr) {
      if (!pack || typeof pack[e] !== 'object') {
        return res.status(400).json({ error: 'bad_request', detail: `missing ${e}` });
      }
      for (const p of points) {
        const pt = pack[e][p];
        if (!pt || typeof pt.x !== 'number' || typeof pt.y !== 'number') {
          return res.status(400).json({ error: 'bad_request', detail: `invalid ${e}.${p} (x/y number required)` });
        }
      }
    }

    await admin.firestore()
      .collection('users').doc(req.uid)
      .collection('initialExpressions').doc('v1')
      .set(pack, { merge: true });

    res.json({ ok: true });
  } catch (err) {
    console.error('EXPRESSIONS_INIT_ERR', err, { body: req.body });
    res.status(500).json({ error: 'server_error', detail: String(err?.message || err) });
  }
});

// 404 & 에러 핸들러
app.use((req, res) => res.status(404).json({ error: 'not_found' }));
app.use((err, req, res, next) => {
  console.error('UNHANDLED', err);
  res.status(500).json({ error: 'server_error', detail: String(err?.message || err) });
});

module.exports = app;
