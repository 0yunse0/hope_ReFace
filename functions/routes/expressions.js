const auth = require('../middlewares/auth');
const ctl  = require('../controllers/expressionsController');
router.post('/initial', auth, ctl.saveInitialExpressions);

router.post('/initial', auth, ctl.saveInitialExpressions);

module.exports = router;