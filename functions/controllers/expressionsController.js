const { admin, db } = require("../firebase");
const { validateLandmarks, EXPRESSIONS } = require("../utils/validator");

const bad = (res, code, msg) => res.status(code).json({ error: msg });

/**
 * 회원가입 직후: 표정 4종 × 8좌표 "내 얼굴 초기값" 저장
 * 유효하지 않은 expr/랜드마크가 하나라도 있으면 전체 저장 취소(400)
 */
exports.saveInitialExpressions = async (req, res) => {
  try {
    const body = req.body || {};
    const expressions = body.expressions;
    if (!expressions || typeof expressions !== "object") {
      return bad(res, 400, "expressions must be object");
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const userRef = db.collection("users").doc(req.uid);

    // 1) 사전 검증 (ALL-or-Nothing)
    for (const expr of Object.keys(expressions)) {
      if (!EXPRESSIONS.has(expr)) {
        return bad(res, 400, `Invalid expression: ${expr}`);
      }
      const err = validateLandmarks(expressions[expr]);
      if (err) {
        return bad(res, 400, err);
      }
    }

    // 2) 배치 커밋
    const batch = db.batch();
    for (const expr of Object.keys(expressions)) {
      batch.set(
        userRef.collection("expressions").doc(expr),
        { personalInitial: expressions[expr], updatedAt: now },
        { merge: true }
      );
    }
    await batch.commit();

    return res.json({ ok: true });
  } catch (e) {
    console.error(e);
    return bad(res, 500, "server_error");
  }
};
