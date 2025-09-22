// app.js
'use strict';

const express = require('express');
const app = express();

app.use(express.json());

// ====== 요청 로깅 (디버깅용) ======
app.use((req, _res, next) => {
  console.log(
    '[REQ]',
    req.method,
    'path=', req.path,
    'baseUrl=', req.baseUrl,
    'originalUrl=', req.originalUrl
  );
  next();
});

// ====== 공개 엔드포인트 (헬스체크/라우트 인스펙터) ======
app.get(['/healthz', '/api/healthz'], (req, res) => {
  res.json({ ok: true, path: req.path });
});

app.get(['/__routes', '/api/__routes'], (req, res) => {
  const routes = [];
  app._router.stack.forEach((m) => {
    if (m.route) {
      const methods = Object.keys(m.route.methods).map((x) => x.toUpperCase());
      routes.push({ path: m.route.path, methods });
    } else if (m.name === 'router') {
      m.handle.stack.forEach((r) => {
        if (r.route) {
          const methods = Object.keys(r.route.methods).map((x) => x.toUpperCase());
          routes.push({ path: r.route.path, methods });
        }
      });
    }
  });
  res.json(routes);
});

// ====== 라우터 & 인증 미들웨어 ======
const requireAuth = require('./middlewares/auth');
const expressionsRouter = require('./routes/expressions');

// ✅ /expressions 와 /api/expressions 모두 인증 후 라우팅
app.use(['/expressions', '/api/expressions'], requireAuth, expressionsRouter);

const trainingRouter = require('./routes/training');
app.use(['/training', '/api/training'], requireAuth, trainingRouter);

// ====== 404 핸들러 ======
app.use((req, res) => {
  console.warn('[404]', req.method, req.path, 'originalUrl=', req.originalUrl);
  res.status(404).json({ error: 'not_found', path: req.path });
});

module.exports = app;
