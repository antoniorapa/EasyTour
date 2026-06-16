const jwt = require('jsonwebtoken');

/*
  Middleware di autenticazione EasyTour.

  verifyToken legge l'header Authorization: "Bearer <token>",
  verifica il JWT e mette i dati utente in req.user.

  requireRole(ruolo) protegge le route riservate a un ruolo specifico,
  ad esempio la dashboard comunale (OPERATORE_COMUNALE).
*/

function verifyToken(req, res, next) {
  const authHeader = req.headers['authorization'];

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      message: 'Token mancante',
    });
  }

  const token = authHeader.substring('Bearer '.length);

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);

    // payload contiene: userId, ruolo, email
    req.user = payload;

    next();
  } catch (error) {
    return res.status(401).json({
      message: 'Token non valido o scaduto',
    });
  }
}

function requireRole(ruoloRichiesto) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        message: 'Utente non autenticato',
      });
    }

    if (req.user.ruolo !== ruoloRichiesto) {
      return res.status(403).json({
        message: 'Accesso non consentito per questo ruolo',
      });
    }

    next();
  };
}

module.exports = {
  verifyToken,
  requireRole,
};
