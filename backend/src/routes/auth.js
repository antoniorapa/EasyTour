const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const { driver } = require('../db');

const router = express.Router();

const SALT_ROUNDS = 10;
const TOKEN_DURATION = '7d';

/*
  Crea il token JWT per un utente autenticato.
  Il payload contiene solo ciò che serve al frontend e ai middleware:
  id utente, ruolo ed email. Mai dati sensibili come la password.
*/
function createToken(user) {
  return jwt.sign(
    {
      userId: user.id,
      ruolo: user.ruolo,
      email: user.email,
    },
    process.env.JWT_SECRET,
    { expiresIn: TOKEN_DURATION }
  );
}

/*
  POST /auth/register/tourist
  Registrazione del turista (Tabella 6.2 del RAD):
  nome, email, password, accettazione condizioni.
*/
router.post('/register/tourist', async (req, res) => {
  const { nome, email, password, accettaCondizioni } = req.body;

  if (!nome || !email || !password) {
    return res.status(400).json({
      message: 'Nome, email e password sono obbligatori',
    });
  }

  if (!accettaCondizioni) {
    return res.status(400).json({
      message: 'È necessario accettare le condizioni del servizio',
    });
  }

  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  try {
    const existing = await session.run(
      `MATCH (u:User {email: $email}) RETURN u LIMIT 1`,
      { email }
    );

    if (existing.records.length > 0) {
      return res.status(409).json({
        message: 'Email già registrata',
      });
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    const userId = `user_${Date.now()}`;

    await session.run(
      `
      CREATE (u:User {
        id: $userId,
        nome: $nome,
        email: $email,
        passwordHash: $passwordHash,
        ruolo: "TURISTA"
      })
      `,
      { userId, nome, email, passwordHash }
    );

    const user = { id: userId, email, ruolo: 'TURISTA' };

    return res.status(201).json({
      message: 'Registrazione turista completata',
      token: createToken(user),
      user: { id: userId, nome, email, ruolo: 'TURISTA' },
    });
  } catch (error) {
    console.error('Errore registrazione turista:', error);

    return res.status(500).json({
      message: 'Errore nella registrazione',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

/*
  POST /auth/register/municipality
  Registrazione dell'operatore comunale (Tabella 6.2 del RAD):
  nome referente, email istituzionale, password, nome Comune,
  ruolo referente, metodo di pagamento, accettazione condizioni.

  L'operatore viene collegato al Comune tramite (u)-[:MANAGES]->(m).
  Il Comune deve già esistere nella piattaforma.
*/
router.post('/register/municipality', async (req, res) => {
  const {
    nome,
    email,
    password,
    nomeComune,
    ruoloReferente,
    metodoPagamento,
    accettaCondizioni,
  } = req.body;

  if (!nome || !email || !password || !nomeComune) {
    return res.status(400).json({
      message:
        'Nome referente, email, password e nome del Comune sono obbligatori',
    });
  }

  if (!accettaCondizioni) {
    return res.status(400).json({
      message: 'È necessario accettare le condizioni del servizio',
    });
  }

  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  try {
    const existing = await session.run(
      `MATCH (u:User {email: $email}) RETURN u LIMIT 1`,
      { email }
    );

    if (existing.records.length > 0) {
      return res.status(409).json({
        message: 'Email già registrata',
      });
    }

    // Il Comune deve essere già presente nella piattaforma.
    const municipalityResult = await session.run(
      `MATCH (m:Municipality) WHERE toLower(m.nome) = toLower($nomeComune) RETURN m LIMIT 1`,
      { nomeComune }
    );

    if (municipalityResult.records.length === 0) {
      return res.status(404).json({
        message:
          'Comune non presente nella piattaforma EasyTour. Contattare l’amministrazione.',
      });
    }

    const municipalityId =
      municipalityResult.records[0].get('m').properties.id;

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    const userId = `user_${Date.now()}`;

    await session.run(
      `
      MATCH (m:Municipality {id: $municipalityId})
      CREATE (u:User {
        id: $userId,
        nome: $nome,
        email: $email,
        passwordHash: $passwordHash,
        ruolo: "OPERATORE_COMUNALE",
        ruoloReferente: $ruoloReferente,
        metodoPagamento: $metodoPagamento
      })
      CREATE (u)-[:MANAGES]->(m)
      `,
      {
        userId,
        nome,
        email,
        passwordHash,
        municipalityId,
        ruoloReferente: ruoloReferente || '',
        metodoPagamento: metodoPagamento || '',
      }
    );

    const user = { id: userId, email, ruolo: 'OPERATORE_COMUNALE' };

    return res.status(201).json({
      message: 'Registrazione operatore comunale completata',
      token: createToken(user),
      user: {
        id: userId,
        nome,
        email,
        ruolo: 'OPERATORE_COMUNALE',
        municipalityId,
      },
    });
  } catch (error) {
    console.error('Errore registrazione operatore comunale:', error);

    return res.status(500).json({
      message: 'Errore nella registrazione',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

/*
  POST /auth/login
  Login unico email/password (cap. 6.5 del RAD).
  Dopo la verifica restituisce il token JWT e il ruolo,
  così il frontend può fare il redirect all'area corretta.
*/
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      message: 'Email e password sono obbligatori',
    });
  }

  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  try {
    const result = await session.run(
      `
      MATCH (u:User {email: $email})
      OPTIONAL MATCH (u)-[:MANAGES]->(m:Municipality)
      RETURN u AS user, m AS municipality
      LIMIT 1
      `,
      { email }
    );

    if (result.records.length === 0) {
      return res.status(401).json({
        message: 'Credenziali non valide',
      });
    }

    const userNode = result.records[0].get('user').properties;
    const municipalityNode = result.records[0].get('municipality');

    const passwordValida = await bcrypt.compare(
      password,
      userNode.passwordHash || ''
    );

    if (!passwordValida) {
      return res.status(401).json({
        message: 'Credenziali non valide',
      });
    }

    const user = {
      id: userNode.id,
      ruolo: userNode.ruolo,
      email: userNode.email,
    };

    return res.json({
      message: 'Login effettuato',
      token: createToken(user),
      user: {
        id: userNode.id,
        nome: userNode.nome,
        email: userNode.email,
        ruolo: userNode.ruolo,
        municipalityId: municipalityNode
          ? municipalityNode.properties.id
          : null,
      },
    });
  } catch (error) {
    console.error('Errore login:', error);

    return res.status(500).json({
      message: 'Errore durante il login',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

module.exports = router;
