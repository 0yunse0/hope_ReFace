const express = require("express");
const router = express.Router();

const requireAuth = require("../middlewares/auth"); // default export
const {
  calcProgress, startSession, saveSet, finalizeSession, listSessions, getSession
} = require("../controllers/trainingController");

router.use(requireAuth);

router.post("/sessions", startSession);
router.post("/sessions/:sid/progress", calcProgress);
router.post("/sessions/:sid/sets", saveSet);
router.put("/sessions/:sid", finalizeSession);
router.get("/sessions", listSessions);
router.get("/sessions/:sid", getSession);

module.exports = router;
