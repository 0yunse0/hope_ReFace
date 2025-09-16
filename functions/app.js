'use strict';

const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

const trainingRouter = require('./routes/training');
const expressionsRouter = require('./routes/expressions'); // ★ 새 라우터

const app = express();

app.use(cors({ origin: true }));
app.use(express.json({ limit: '1mb' }));

app.get('/health', (req, res) => res.json({ ok: true }));

const authGuard = async (req, res, next) => {
  try {
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
      return res.status(401).json({
        error: 'unauthorized',
        detail: 'Missing Bearer token',
      });
    }

    const decoded = await admin.auth().verifyIdToken(m[1]);
    req.uid = decoded.uid;
    req.user = { uid: decoded.uid, token: decoded };
    next();
  } catch (err) {
    res.status(401).json({
      error: 'unauthorized',
      detail: String(err?.message || err),
    });
  }
};

// 초기표정 "점수" 저장용 라우터 (POST /expressions/scores)
app.use('/expressions', authGuard, expressionsRouter);

// 훈련 API (세션/완료/조회 등)
app.use('/training', authGuard, trainingRouter);

// 404 & 에러 핸들러
app.use((req, res) => res.status(404).json({ error: 'not_found' }));
app.use((err, req, res, next) => {
  console.error('UNHANDLED', err);
  res.status(500).json({ error: 'server_error', detail: String(err?.message || err) });
});

module.exports = app;
