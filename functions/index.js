'use strict';

// .env 로드(있으면)
try {
  require('dotenv').config();
} catch {/* env 파일이 없어도 무시 */}

// Firebase Admin 초기화 (필요 시)
const { initializeApp: initAdmin, getApps } = require('firebase-admin/app');
if (!getApps().length) {
  // Functions/에뮬레이터 환경에서는 기본 자격증명을 자동 사용
  initAdmin();
}

// Functions v2: HTTPS onRequest
const { onRequest } = require('firebase-functions/v2/https');

// Express 앱
const app = require('./app');

/**
 * Cloud Functions 엔드포인트
 */
exports.api = onRequest(
  {
    region: 'us-central1',
    cors: true,
    timeoutSeconds: 60,
    memory: '512MiB',
  },
  (req, res) => {
    // 공통 컨텍스트 전달(테스트 바이패스 등)
    res.locals.testBypass = process.env.ENABLE_TEST_BYPASS === '1';
    return app(req, res);
  }
);

/**
 * 로컬 단독 실행(선택): `node index.js`
 * - 에뮬레이터가 아니라 Express만 띄워 빠르게 테스트하고 싶을 때 사용하면 됨!!
 */
if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`[local] Express listening on http://localhost:${PORT}`);
    console.log(`[local] TEST_BYPASS=${process.env.ENABLE_TEST_BYPASS}`);
  });
}
