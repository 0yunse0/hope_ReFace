// app.js
'use strict';

const express = require('express');
const app = express();

app.use(express.json());

// 요청 경로 관찰용(임시)
app.use((req, _res, next) => {
  console.log('[REQ]', req.method, req.path);
  next();
});

// 헬스체크 엔드포인트(배포 후 바로 확인용)
app.get(['/healthz', '/api/healthz'], (req, res) => {
  res.json({ ok: true, path: req.path });
});

// --- 라우트 마운트 ---
const expressionsRouter = require('./routes/expressions');

// 둘 다 받기: /expressions/* 와 /api/expressions/*
// (Hosting에서 /api/* 로 들어와도 매칭되도록)
app.use(['/expressions', '/api/expressions'], expressionsRouter);


app.get(['/__routes', '/api/__routes'], (req, res) => {
  const routes = [];
  app._router.stack.forEach((middleware) => {
    if (middleware.route) { // 직접 라우트
      const methods = Object.keys(middleware.route.methods).map((m) => m.toUpperCase());
      routes.push({ path: middleware.route.path, methods });
    } else if (middleware.name === 'router') { // 서브 라우터
      middleware.handle.stack.forEach((r) => {
        const route = r.route;
        if (route) {
          const methods = Object.keys(route.methods).map((m) => m.toUpperCase());
          routes.push({ path: route.path, methods });
        }
      });
    }
  });
  res.json(routes);
});


// 404 핸들러(무엇이 안 맞는지 확인)
app.use((req, res) => {
  console.warn('[404]', req.method, req.path);
  res.status(404).json({ error: 'not_found', path: req.path });
});

module.exports = app;
