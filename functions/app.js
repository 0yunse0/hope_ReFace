// functions/app.js
const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

const trainingRouter = require('./routes/training'); // <-- 훈련 라우터 추가

const app = express();

app.use(cors({ origin: true }));
app.use(express.json({ limit: '1mb' }));

// 헬스체크
app.get('/health', (req, res) => res.json({ ok: true }));

// 인증 미들웨어 (웹/앱용 Bearer 토큰 + 선택적 테스트 바이패스)
const authGuard = async (req, res, next) => {
  try {
    // (선택) 테스트 바이패스: ENABLE_TEST_BYPASS=1 && x-test-uid 헤더가 있으면 토큰 없이 통과
    if (process.env.ENABLE_TEST_BYPASS === '1') {
      const testUid = req.headers['x-test-uid'];
      if (typeof testUid === 'string' && testUid.length > 0) {
        req.uid = testUid;
        req.user = { uid: testUid };
        return next();
      }
    }

    const auth = req.headers.authorization || '';
    const m = auth.match(/^Bearer (.+)$/);
    if (!m) {
      return res
        .status(401)
        .json({ error: 'unauthorized', detail: 'Missing Bearer token' });
    }

    const decoded = await admin.auth().verifyIdToken(m[1]);
    req.uid = decoded.uid;
    req.user = { uid: decoded.uid, token: decoded }; // 컨트롤러 호환용
    next();
  } catch (err) {
    res
      .status(401)
      .json({ error: 'unauthorized', detail: String(err?.message || err) });
  }
};

// ---------- 초기 표정 저장(인라인) ----------
app.post('/expressions/initial', authGuard, async (req, res) => {
  try {
    const { expressions, smile, angry, sad, neutral } = req.body || {};
    const pack = expressions ?? { smile, angry, sad, neutral };

    const requiredExpr = ['smile', 'angry', 'sad', 'neutral'];
    const points = [
      'bottomMouth',
      'rightMouth',
      'leftMouth',
      'leftEye',
      'rightEye',
      'rightCheek',
      'leftCheek',
      'noseBase',
    ];

    for (const e of requiredExpr) {
      if (!pack || typeof pack[e] !== 'object') {
        return res
          .status(400)
          .json({ error: 'bad_request', detail: `missing ${e}` });
      }
      for (const p of points) {
        const pt = pack[e][p];
        if (!pt || typeof pt.x !== 'number' || typeof pt.y !== 'number') {
          return res.status(400).json({
            error: 'bad_request',
            detail: `invalid ${e}.${p} (x/y number required)`,
          });
        }
      }
    }

    await admin
      .firestore()
      .collection('users')
      .doc(req.uid)
      .collection('initialExpressions')
      .doc('v1')
      .set(pack, { merge: true });

    res.json({ ok: true });
  } catch (err) {
    console.error('EXPRESSIONS_INIT_ERR', err, { body: req.body });
    res
      .status(500)
      .json({ error: 'server_error', detail: String(err?.message || err) });
  }
});

// ---------- 훈련 API (세션/세트/완료/조회) ----------
app.use('/training', authGuard, trainingRouter); // <-- 핵심: 라우트 장착

// 404 & 에러 핸들러
app.use((req, res) => res.status(404).json({ error: 'not_found' }));
app.use((err, req, res, next) => {
  console.error('UNHANDLED', err);
  res
    .status(500)
    .json({ error: 'server_error', detail: String(err?.message || err) });
});

module.exports = app;
