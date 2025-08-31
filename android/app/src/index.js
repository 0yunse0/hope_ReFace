// functions/index.js
const functions = require('firebase-functions');
const express = require('express');
const cors = require('cors');

const app = express();
app.use(express.json());
app.use(cors({ origin: true }));

// 브라우저 확인용 GET
app.get('/ping', (req, res) => {
  res.status(200).json({ ok: true, ts: Date.now() });
});

// Flutter가 호출할 POST
app.post('/training/captures', (req, res) => {
  console.log('payload', req.body);
  res.sendStatus(204);
});

// 꼭 한 번만 export
exports.api = functions.region('us-central1').https.onRequest(app);
