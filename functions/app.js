const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// routes
app.use('/expressions', require('./routes/expressions'));

module.exports = app;