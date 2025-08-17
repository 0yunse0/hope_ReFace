const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp();

const app = require('./app');
exports.api = onRequest({ region: 'asia-northeast3', cors: true }, app);