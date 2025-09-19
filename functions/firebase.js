'use strict';

/**
 * Firebase Admin 초기화 단일화
 * - Cloud Functions(v2) 환경에서는 별도 서비스키 없이 initializeApp()만으로 동작
 * - 로컬/CI 등에서는 GOOGLE_APPLICATION_CREDENTIALS 혹은 applicationDefault() 사용
 */

const admin = require('firebase-admin');
const { getApps, initializeApp, applicationDefault } = require('firebase-admin/app');

if (!getApps().length) {
  try {
    // 로컬/CI에서 ADC가 있으면 이 경로로 초기화
    initializeApp({ credential: applicationDefault() });
  } catch (_e) {
    // Cloud Functions 런타임 등에서는 옵션 없이도 동작
    initializeApp();
  }
}

const db = admin.firestore();

module.exports = { admin, db };
