const express = require("express");
const router = express.Router();

const requireAuth = require("../middlewares/auth"); // default export
const { saveInitialExpressions } = require("../controllers/expressionsController");

// 인증 붙여서 한 번만 등록
router.post("/initial", requireAuth, saveInitialExpressions);

module.exports = router;
