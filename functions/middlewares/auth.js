// functions/middlewares/auth.js
const { admin } = require('../firebase');

/**
 * Firebase ID Token을 검증해 req.user.uid / req.uid 세팅
 * - Authorization: Bearer <ID_TOKEN>
 */
async function requireAuth(req, res, next) {
  try {
    if (process.env.ENABLE_TEST_BYPASS === "1") {
      const testUid = req.headers["x-test-uid"];
      if (testUid && typeof testUid === "string" && testUid.length > 0) {
        req.uid = testUid;
        req.user = { uid: testUid, token: null };
        return next();
      }
    } // 윤서야 이 if문 테스트 용이야 나중에 지워야됨!
    // CORS preflight는 통과
    if (req.method === "OPTIONS") return next();

    const h = req.headers.authorization || "";
    const m = h.match(/^Bearer\s+(.+)$/i);
    if (!m) return res.status(401).json({ error: "Missing Bearer token" });

    const decoded = await admin.auth().verifyIdToken(m[1]);

    // 호환성: 둘 다 세팅해 컨트롤러 코드 수정 최소화
    req.uid = decoded.uid;
    req.user = { uid: decoded.uid, token: decoded };

    return next();
  } catch (e) {
    console.error("[auth] token verify failed:", e?.message || e);
    return res.status(401).json({ error: "Invalid token" });
  }
}

module.exports = requireAuth;
