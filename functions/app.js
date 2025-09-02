const express = require('express');
const cors = require('cors');

const expressionsRouter = require('./routes/expressions');
const trainingRouter = require('./routes/training');

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

app.use('/expressions', expressionsRouter);
app.use('/training', trainingRouter);

module.exports = app;
