const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

const { driver } = require('../db');

const router = express.Router();

const SALT_ROUNDS = 10;
const TOKEN_DURATION = '7d';

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

function normalizeText(value) {
  return value ? value.toString().trim() : '';
}

function normalizeCode(value) {
  return value ? value.toString().trim().toUpperCase() : '';
}

function isTrue(value) {
  return value === true || value === 'true';
}

/*
  POST /auth/register/tourist
  Registrazione del turista.
*/
router.post('/register/tourist', async (req, res) => {
  const { nome, email, password, accettaCondizioni } = req.body;

  const cleanNome = normalizeText(nome);
  const cleanEmail = normalizeText(email).toLowerCase();

  if (!cleanNome || !cleanEmail || !password) {
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
      `
      MATCH (u:User {email: $email})
      RETURN u
      LIMIT 1
      `,
      { email: cleanEmail }
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
        ruolo: "TURISTA",
        dataRegistrazione: datetime()
      })
      `,
      {
        userId,
        nome: cleanNome,
        email: cleanEmail,
        passwordHash,
      }
    );

    const user = {
      id: userId,
      email: cleanEmail,
      ruolo: 'TURISTA',
    };

    return res.status(201).json({
      message: 'Registrazione turista completata',
      token: createToken(user),
      user: {
        id: userId,
        nome: cleanNome,
        email: cleanEmail,
        ruolo: 'TURISTA',
      },
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

  Logica:
  - Il Comune deve già esistere in Neo4j.
  - Il codiceAttivazione deve essere corretto.
  - Se il Comune non è ancora attivo, il primo operatore deve inserire
    il metodo di pagamento del Comune.
  - Dopo la prima registrazione, il Comune diventa servizioAttivo = true.
  - Gli operatori successivi possono registrarsi senza reinserire il pagamento.
*/
router.post('/register/municipality', async (req, res) => {
  const {
    nome,
    email,
    password,
    nomeComune,
    codiceAttivazione,
    ruoloReferente,
    metodoPagamento,
    accettaCondizioni,
  } = req.body;

  const cleanNome = normalizeText(nome);
  const cleanEmail = normalizeText(email).toLowerCase();
  const cleanNomeComune = normalizeText(nomeComune);
  const cleanCodiceAttivazione = normalizeCode(codiceAttivazione);
  const cleanRuoloReferente = normalizeText(ruoloReferente);
  const cleanMetodoPagamento = normalizeText(metodoPagamento);

  if (
    !cleanNome ||
    !cleanEmail ||
    !password ||
    !cleanNomeComune ||
    !cleanCodiceAttivazione
  ) {
    return res.status(400).json({
      message:
        'Nome referente, email, password, nome del Comune e codice di attivazione sono obbligatori',
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
      `
      MATCH (u:User {email: $email})
      RETURN u
      LIMIT 1
      `,
      { email: cleanEmail }
    );

    if (existing.records.length > 0) {
      return res.status(409).json({
        message: 'Email già registrata',
      });
    }

    const municipalityResult = await session.run(
      `
      MATCH (m:Municipality)
      WHERE toLower(m.nome) = toLower($nomeComune)
      RETURN m
      LIMIT 1
      `,
      { nomeComune: cleanNomeComune }
    );

    if (municipalityResult.records.length === 0) {
      return res.status(404).json({
        message:
          'Comune non presente nella piattaforma EasyTour. Contattare l’amministrazione.',
      });
    }

    const municipalityNode = municipalityResult.records[0].get('m').properties;
    const municipalityId = municipalityNode.id;
    const codiceDb = normalizeCode(municipalityNode.codiceAttivazione);

    if (!codiceDb || codiceDb !== cleanCodiceAttivazione) {
      return res.status(403).json({
        message: 'Codice di attivazione non valido per il Comune indicato.',
      });
    }

    const servizioAttivo = isTrue(municipalityNode.servizioAttivo);
    const metodoPagamentoConfigurato = isTrue(
      municipalityNode.metodoPagamentoConfigurato
    );

    const comuneGiaAttivo =
      servizioAttivo === true && metodoPagamentoConfigurato === true;

    if (!comuneGiaAttivo && !cleanMetodoPagamento) {
      return res.status(400).json({
        message:
          'Per attivare il servizio del Comune è necessario inserire il metodo di pagamento del Comune.',
      });
    }

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
        dataRegistrazione: datetime()
      })

      CREATE (u)-[:MANAGES]->(m)

      SET
        m.servizioAttivo = true,
        m.metodoPagamentoConfigurato = true,
        m.metodoPagamento = CASE
          WHEN m.metodoPagamento IS NULL OR m.metodoPagamento = ""
          THEN $metodoPagamento
          ELSE m.metodoPagamento
        END,
        m.dataAttivazioneServizio = CASE
          WHEN m.dataAttivazioneServizio IS NULL
          THEN datetime()
          ELSE m.dataAttivazioneServizio
        END
      `,
      {
        userId,
        nome: cleanNome,
        email: cleanEmail,
        passwordHash,
        municipalityId,
        ruoloReferente: cleanRuoloReferente,
        metodoPagamento: cleanMetodoPagamento,
      }
    );

    const user = {
      id: userId,
      email: cleanEmail,
      ruolo: 'OPERATORE_COMUNALE',
    };

    const firstActivation = !comuneGiaAttivo;

    return res.status(201).json({
      message: firstActivation
        ? 'Registrazione completata. Il servizio del Comune è stato attivato.'
        : 'Registrazione operatore comunale completata.',
      token: createToken(user),
      user: {
        id: userId,
        nome: cleanNome,
        email: cleanEmail,
        ruolo: 'OPERATORE_COMUNALE',
        ruoloReferente: cleanRuoloReferente,
        municipalityId,
        municipalityName: municipalityNode.nome,
      },
      municipality: {
        id: municipalityId,
        nome: municipalityNode.nome,
        servizioAttivo: true,
        metodoPagamentoConfigurato: true,
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
  Login unico email/password.
*/
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  const cleanEmail = normalizeText(email).toLowerCase();

  if (!cleanEmail || !password) {
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
      { email: cleanEmail }
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

    const municipality = municipalityNode
      ? municipalityNode.properties
      : null;

    return res.json({
      message: 'Login effettuato',
      token: createToken(user),
      user: {
        id: userNode.id,
        nome: userNode.nome,
        email: userNode.email,
        ruolo: userNode.ruolo,
        ruoloReferente: userNode.ruoloReferente || null,
        municipalityId: municipality ? municipality.id : null,
        municipalityName: municipality ? municipality.nome : null,
        servizioAttivo: municipality
          ? isTrue(municipality.servizioAttivo)
          : null,
        metodoPagamentoConfigurato: municipality
          ? isTrue(municipality.metodoPagamentoConfigurato)
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