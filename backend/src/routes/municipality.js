const express = require('express');
const { driver } = require('../db');

const router = express.Router();

function neo4jNumberToJs(value) {
  if (value === null || value === undefined) return 0;

  if (typeof value === 'number') {
    return value;
  }

  if (value && typeof value.toNumber === 'function') {
    return value.toNumber();
  }

  if (value && typeof value.low === 'number') {
    return value.low;
  }

  const parsed = Number(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function neo4jDateToString(value) {
  if (!value) return null;

  if (typeof value === 'string') {
    return value;
  }

  if (typeof value.toString === 'function') {
    return value.toString();
  }

  return null;
}

function normalizeText(value) {
  return (value || '')
    .toString()
    .trim()
    .toLowerCase()
    .replaceAll("'", '')
    .replaceAll('à', 'a')
    .replaceAll('è', 'e')
    .replaceAll('é', 'e')
    .replaceAll('ì', 'i')
    .replaceAll('ò', 'o')
    .replaceAll('ù', 'u');
}

function isTrue(value) {
  return value === true || value === 'true';
}

function normalizeMunicipalityFromProperties(m) {
  const servizioAttivo =
    isTrue(m.servizioAttivo) || m.statoServizio === 'ATTIVO';

  const metodoPagamentoConfigurato =
    isTrue(m.metodoPagamentoConfigurato) ||
    Boolean(m.metodoPagamento && m.metodoPagamento.toString().trim() !== '');

  const active = servizioAttivo && metodoPagamentoConfigurato;

  return {
    id: m.id,
    nome: m.nome,
    provincia: m.provincia || '',
    regione: m.regione || '',

    latitudine: Number(neo4jNumberToJs(m.latitudine) || 0),
    longitudine: Number(neo4jNumberToJs(m.longitudine) || 0),

    codiceAttivazione: m.codiceAttivazione || null,

    servizioAttivo,
    metodoPagamentoConfigurato,
    metodoPagamento: m.metodoPagamento || null,
    dataAttivazioneServizio: neo4jDateToString(m.dataAttivazioneServizio),

    statoServizio: active ? 'ATTIVO' : 'NON_ATTIVO',

    active,
  };
}

function normalizeMunicipality(record) {
  const municipalityNode = record.get('municipality');

  if (!municipalityNode) {
    return null;
  }

  return normalizeMunicipalityFromProperties(municipalityNode.properties);
}

async function findMunicipalityInNeo4jByName(query) {
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  const cleanedQuery = normalizeText(query);

  try {
    const result = await session.run(
      `
      MATCH (m:Municipality)
      WITH m,
           toLower(m.nome) AS nomeLower,
           toLower($query) AS queryLower
      WITH m, nomeLower, queryLower,
           CASE
             WHEN nomeLower = queryLower THEN 0
             WHEN nomeLower STARTS WITH queryLower THEN 1
             WHEN nomeLower CONTAINS queryLower THEN 2
             WHEN queryLower CONTAINS nomeLower THEN 3
             ELSE 99
           END AS score
      WHERE score < 99
      RETURN m AS municipality, score
      ORDER BY score ASC, size(m.nome) ASC
      LIMIT 1
      `,
      {
        query: cleanedQuery,
      }
    );

    if (result.records.length === 0) {
      return null;
    }

    return normalizeMunicipality(result.records[0]);
  } finally {
    await session.close();
  }
}

function toRadians(degrees) {
  return (degrees * Math.PI) / 180;
}

function calculateDistanceKm(lat1, lon1, lat2, lon2) {
  const earthRadiusKm = 6371;

  const dLat = toRadians(Number(lat2) - Number(lat1));
  const dLon = toRadians(Number(lon2) - Number(lon1));

  const rLat1 = toRadians(Number(lat1));
  const rLat2 = toRadians(Number(lat2));

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLon / 2) *
      Math.sin(dLon / 2) *
      Math.cos(rLat1) *
      Math.cos(rLat2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return earthRadiusKm * c;
}

/*
  GET /municipality/search?q=Napoli

  Restituisce il Comune anche se non è attivo.
  Il frontend deve usare active/servizioAttivo per decidere se bloccare le funzioni.
*/
router.get('/search', async (req, res) => {
  const query = req.query.q;

  if (!query) {
    return res.status(400).json({
      found: false,
      active: false,
      servizioAttivo: false,
      message: 'Parametro q mancante',
    });
  }

  try {
    const municipality = await findMunicipalityInNeo4jByName(query);

    if (!municipality) {
      return res.json({
        found: false,
        active: false,
        servizioAttivo: false,
        metodoPagamentoConfigurato: false,
        message: 'Comune non presente nella piattaforma EasyTour',
      });
    }

    return res.json({
      found: true,
      ...municipality,
      message: municipality.active
        ? 'Comune attivo'
        : 'Comune presente nella piattaforma, ma il servizio non è ancora attivo',
    });
  } catch (error) {
    console.error('Errore ricerca Comune:', error);

    return res.status(500).json({
      found: false,
      active: false,
      servizioAttivo: false,
      message: 'Errore nella ricerca del Comune',
      error: error.message,
    });
  }
});

/*
  GET /municipality/check-point?lat=...&lng=...

  Cerca il Comune più vicino al punto scelto.
  Restituisce anche se non attivo, ma active=false.
*/
router.get('/check-point', async (req, res) => {
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);

  if (Number.isNaN(lat) || Number.isNaN(lng)) {
    return res.status(400).json({
      found: false,
      active: false,
      servizioAttivo: false,
      message: 'Parametri lat e lng obbligatori',
    });
  }

  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  try {
    const result = await session.run(
      `
      MATCH (m:Municipality)
      WHERE m.latitudine IS NOT NULL
        AND m.longitudine IS NOT NULL
      RETURN m AS municipality
      `
    );

    if (result.records.length === 0) {
      return res.json({
        found: false,
        active: false,
        servizioAttivo: false,
        message: 'Nessun Comune EasyTour ha coordinate registrate.',
      });
    }

    const municipalities = result.records
      .map((record) => normalizeMunicipality(record))
      .filter((municipality) => municipality !== null)
      .map((municipality) => {
        const distanceKm = calculateDistanceKm(
          lat,
          lng,
          municipality.latitudine,
          municipality.longitudine
        );

        return {
          ...municipality,
          distanceKm,
        };
      });

    municipalities.sort((a, b) => a.distanceKm - b.distanceKm);

    const nearestMunicipality = municipalities[0];

    const maxDistanceFromMunicipalityCenterKm =
      nearestMunicipality.nome === 'Roma' ? 25 : 8;

    if (nearestMunicipality.distanceKm > maxDistanceFromMunicipalityCenterKm) {
      return res.json({
        found: false,
        active: false,
        servizioAttivo: false,
        detectedMunicipalityName: null,
        nearestMunicipalityName: nearestMunicipality.nome,
        nearestDistanceKm: Number(nearestMunicipality.distanceKm.toFixed(2)),
        message:
          `Il punto selezionato non rientra in un Comune EasyTour. ` +
          `Il Comune registrato più vicino è ${nearestMunicipality.nome}, ` +
          `a ${nearestMunicipality.distanceKm.toFixed(2)} km.`,
      });
    }

    return res.json({
      found: true,
      detectedMunicipalityName: nearestMunicipality.nome,
      nearestDistanceKm: Number(nearestMunicipality.distanceKm.toFixed(2)),
      ...nearestMunicipality,
      message: nearestMunicipality.active
        ? `Il punto selezionato rientra nell'area del Comune attivo di ${nearestMunicipality.nome}.`
        : `Il punto selezionato rientra nell'area del Comune di ${nearestMunicipality.nome}, ma il servizio EasyTour non è ancora attivo.`,
    });
  } catch (error) {
    console.error('Errore check-point Comune:', error);

    return res.status(500).json({
      found: false,
      active: false,
      servizioAttivo: false,
      message: 'Errore nel controllo del punto selezionato',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

/*
  GET /municipality/:municipalityId/status

  Verifica lo stato del Comune.
*/
router.get('/:municipalityId/status', async (req, res) => {
  const { municipalityId } = req.params;

  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  try {
    const result = await session.run(
      `
      MATCH (m:Municipality {id: $municipalityId})
      RETURN m AS municipality
      LIMIT 1
      `,
      {
        municipalityId,
      }
    );

    if (result.records.length === 0) {
      return res.status(404).json({
        found: false,
        active: false,
        servizioAttivo: false,
        message: 'Comune non trovato',
      });
    }

    const municipality = normalizeMunicipality(result.records[0]);

    return res.json({
      found: true,
      ...municipality,
      message: municipality.active ? 'Comune attivo' : 'Comune non attivo',
    });
  } catch (error) {
    console.error('Errore stato Comune:', error);

    return res.status(500).json({
      found: false,
      active: false,
      servizioAttivo: false,
      message: 'Errore nella verifica del Comune',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

module.exports = router;