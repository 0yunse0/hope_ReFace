process.env.ENABLE_TEST_BYPASS = "1";// 윤서야 이건 테스트용이야 나중에 지워야됨!!

const { onRequest } = require("firebase-functions/v2/https");
const app = require("./app");

exports.api = onRequest({ region: "us-central1" }, app);
