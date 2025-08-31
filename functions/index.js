// functions/index.js  (CommonJS)
const express = require('express');
const cors = require('cors');
const { onRequest } = require('firebase-functions/v2/https'); // <- 딱 1번만!

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

app.post('/training/captures', async (req, res) => {
  console.log('payload', req.body); // 에뮬레이터 터미널에 찍힙니다.
  // TODO: Firestore에 저장 등
  res.status(204).send();
});

// us-central1 리전에 배치
exports.api = onRequest({ region: 'us-central1' }, app);
