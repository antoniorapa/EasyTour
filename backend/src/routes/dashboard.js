const express = require('express');
const router = express.Router();

const { driver } = require('../db');
const { verifyToken, requireRole } = require('../middleware/auth');

/*
  Dashboard comunale (RF-C1..C7).
  Tutte le route sono protette: solo un OPERATORE_COMUNALE autenticato
  può accedere ai dati aggregati del proprio Comune.

  STUB Fase 1: per ora una sola route di prova che conferma
  l'accesso protetto. Le query di aggregazione arrivano in Fase 2.
*/

router.get('/ping', verifyToken, requireRole('OPERATORE_COMUNALE'), (req, res) => {
  res.json({
    message: 'Dashboard accessibile',
    operatore: req.user.email,
  });
});

module.exports = router;
