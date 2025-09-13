'use strict';

try {
  require('dotenv').config();
} catch (e) {
  // .env는 선택사항이라 실패해도 무시
  void e; // 빈 블록 방지용 no-op (ESLint no-empty 해결)
}

const { initializeApp, getApps } = require('firebase-admin/app');
if (!getApps().length) initializeApp();

const { onRequest } = require('firebase-functions/v2/https');
const app = require('./app');

//    모든 라우팅은 app.js -> routes/* 에서만

exports.api = onRequest(
  { region: 'us-central1', cors: true, timeoutSeconds: 60, memory: '512MiB' },
  (req, res) => app(req, res)
);

// (선택) 로컬 단독 실행
if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`[local] Express listening on http://localhost:${PORT}`);
  });
}
