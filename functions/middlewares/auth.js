const admin = require('firebase-admin');

module.exports = async (req, res, next) => {
  try {
    const h = req.headers.authorization || '';
    const m = h.match(/^Bearer (.+)$/);
    if (!m) return res.status(401).json({ error: 'Missing Bearer token' });
    const decoded = await admin.auth().verifyIdToken(m[1]);
    req.uid = decoded.uid;
    next();
  } catch (e) {
    res.status(401).json({ error: 'Invalid token' });
  }
};