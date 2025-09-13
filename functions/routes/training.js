// functions/routes/training.js
// 프론트가 baseline/reference를 안 보내도
// users/{uid}/initialExpressions/v1 에서 불러와 req.body에 주입

const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');

const requireAuth = require('../middlewares/auth');
const {
  calcProgress,
  startSession,
  saveSet,
  finalizeSession,
  listSessions,
  getSession,
  getRecommendations,
} = require('../controllers/trainingController');

const db = admin.firestore();

/**
 * baseline/reference가 요청 바디에 없으면
 *  1) req.uid(토큰에서)와 sid를 사용해 세션 문서(users/{uid}/trainingSessions/{sid}) 확인
 *  2) users/{uid}/initialExpressions/v1에서
 *     baseline(보통 neutral)과 reference(expr)을 불러와 주입
 */
async function attachInitialsIfMissing(req, res, next) {
  try {
    const { baseline, reference, frames } = req.body || {};
    if (!Array.isArray(frames) || frames.length === 0) {
      return res.status(400).json({ error: 'INVALID_FRAMES' });
    }
    // 이미 둘 다 있으면 그대로 진행
    if (baseline && reference) return next();

    const uid = req.uid || req.user?.uid;
    const { sid } = req.params;
    if (!uid) return res.status(401).json({ error: 'unauthorized' });

    // ✅ 세션은 users/{uid}/trainingSessions/{sid} 에 있음
    const sessRef = db.collection('users').doc(uid)
      .collection('trainingSessions').doc(sid);
    const sessSnap = await sessRef.get();
    if (!sessSnap.exists) {
      return res.status(404).json({ error: 'SESSION_NOT_FOUND' });
    }
    const { expr } = sessSnap.data() || {};
    if (!expr) {
      return res.status(400).json({ error: 'SESSION_MISSING_EXPR' });
    }

    // 초기표정 로드
    const initSnap = await db
      .collection('users').doc(uid)
      .collection('initialExpressions').doc('v1')
      .get();

    if (!initSnap.exists) {
      return res.status(400).json({ error: 'INIT_EXPRESSIONS_NOT_FOUND' });
    }

    const init = initSnap.data() || {};
    const base = init.neutral || init[expr]; // 보통 neutral을 baseline으로, 없으면 expr
    const ref = init[expr];

    if (!base || !ref) {
      return res.status(400).json({ error: 'INIT_EXPRESSIONS_MISSING_KEYS' });
    }

    // 요청 바디에 주입(프론트가 안 보냈을 때만)
    req.body.baseline = req.body.baseline || base;
    req.body.reference = req.body.reference || ref;

    return next();
  } catch (err) {
    console.error('attachInitialsIfMissing error', err);
    return res.status(500).json({ error: 'server_error' });
  }
}

// 라우트 등록
router.use(requireAuth);

router.post('/sessions', startSession);
router.post('/sessions/:sid/progress', calcProgress);

// saveSet 전에 baseline/reference 자동 채우기
router.post('/sessions/:sid/sets', attachInitialsIfMissing, saveSet);

router.put('/sessions/:sid', finalizeSession);
router.get('/sessions', listSessions);
router.get('/sessions/:sid', getSession);

// 추천 (정식 경로: /training/recommendations)
router.get('/recommendations', getRecommendations);

module.exports = router;
