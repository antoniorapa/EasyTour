const express = require('express');
const axios = require('axios');
const { driver } = require('../db');

const router = express.Router();

function neo4jNumberToJs(value) {
  if (value && typeof value.toNumber === 'function') {
    return value.toNumber();
  }

  if (value && typeof value.low === 'number') {
    return value.low;
  }

  return value;
}

function normalizeText(value) {
  return value
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

function normalizeMunicipality(record) {
  const municipality = record.get('municipality');
  const subscription = record.get('subscription');

  const m = municipality.properties;
  const s = subscription ? subscription.properties : null;

  const subscriptionActive = s?.stato === 'ATTIVO';
  const municipalityActive = m.statoServizio === 'ATTIVO';

  return {
    id: m.id,
    nome: m.nome,
    provincia: m.provincia || '',
    regione: m.regione || '',
    statoServizio: m.statoServizio || 'NON_ATTIVO',
    latitudine: Number(neo4jNumberToJs(m.latitudine) || 0),
    longitudine: Number(neo4jNumberToJs(m.longitudine) || 0),
    subscription: s
      ? {
          piano: s.piano,
          stato: s.stato,
          metodoPagamento: s.metodoPagamento,
          dataInizio: s.dataInizio?.toString?.() || null,
          dataFine: s.dataFine?.toString?.() || null,
        }
      : null,
    active: municipalityActive && subscriptionActive,
  };
}

async function findMunicipalityInNeo4jByName(query) {
  const session = driver.session();

  const cleanedQuery = normalizeText(query);

  try {
    /*
      Prima cerchiamo una corrispondenza esatta sul nome normalizzato.
      Poi, se non esiste, accettiamo un match parziale.
      Questo evita che la ricerca restituisca sempre un Comune sbagliato.
    */
    const result = await session.run(
      `
      MATCH (m:Municipality)
      OPTIONAL MATCH (m)-[:HAS_SUBSCRIPTION]->(s:Subscription)
      WITH m, s,
           toLower(m.nome) AS nomeLower,
           toLower($query) AS queryLower
      WITH m, s, nomeLower, queryLower,
           CASE
             WHEN nomeLower = queryLower THEN 0
             WHEN nomeLower STARTS WITH queryLower THEN 1
             WHEN nomeLower CONTAINS queryLower THEN 2
             WHEN queryLower CONTAINS nomeLower THEN 3
             ELSE 99
           END AS score
      WHERE score < 99
      RETURN m AS municipality, s AS subscription, score
      ORDER BY score ASC, size(m.nome) ASC
      LIMIT 1
      `,
      {
        query: cleanedQuery,
      },
    );

    if (result.records.length === 0) {
      return null;
    }

    return normalizeMunicipality(result.records[0]);
  } finally {
    await session.close();
  }
}

function extractMunicipalityNameFromGeocoding(results) {
  /*
    In Italia il Comune viene spesso restituito come
    administrative_area_level_3.

    locality può invece essere una frazione o località interna,
    ad esempio Lancusi, Penta, ecc.
    Per EasyTour ci interessa il Comune convenzionato.
  */

  for (const result of results) {
    const components = result.address_components || [];

    const administrativeLevel3 = components.find((component) =>
      component.types.includes('administrative_area_level_3'),
    );

    if (administrativeLevel3) {
      return administrativeLevel3.long_name;
    }
  }

  for (const result of results) {
    const components = result.address_components || [];

    const locality = components.find((component) =>
      component.types.includes('locality'),
    );

    if (locality) {
      return locality.long_name;
    }
  }

  for (const result of results) {
    const components = result.address_components || [];

    const administrativeLevel2 = components.find((component) =>
      component.types.includes('administrative_area_level_2'),
    );

    if (administrativeLevel2) {
      return administrativeLevel2.long_name;
    }
  }

  return null;
}

router.get('/search', async (req, res) => {
  const query = req.query.q;

  if (!query) {
    return res.status(400).json({
      message: 'Parametro q mancante',
    });
  }

  try {
    const municipality = await findMunicipalityInNeo4jByName(query);

    if (!municipality) {
      return res.json({
        found: false,
        active: false,
        message: 'Comune non presente nella piattaforma EasyTour',
      });
    }

    return res.json({
      found: true,
      ...municipality,
      message: municipality.active
        ? 'Comune attivo'
        : 'Comune presente ma non attivo',
    });
  } catch (error) {
    console.error('Errore ricerca Comune:', error);

    return res.status(500).json({
      message: 'Errore nella ricerca del Comune',
      error: error.message,
    });
  }
});
function toRadians(degrees) {
  return degrees * Math.PI / 180;
}

function calculateDistanceKm(lat1, lon1, lat2, lon2) {
  const earthRadiusKm = 6371;

  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);

  const rLat1 = toRadians(lat1);
  const rLat2 = toRadians(lat2);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLon / 2) *
      Math.sin(dLon / 2) *
      Math.cos(rLat1) *
      Math.cos(rLat2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return earthRadiusKm * c;
}
router.get('/check-point', async (req, res) => {
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);

  if (!lat || !lng) {
    return res.status(400).json({
      message: 'Parametri lat e lng obbligatori',
    });
  }

  const session = driver.session();

  try {
    const result = await session.run(
      `
      MATCH (m:Municipality)
      OPTIONAL MATCH (m)-[:HAS_SUBSCRIPTION]->(s:Subscription)
      WHERE m.latitudine IS NOT NULL
        AND m.longitudine IS NOT NULL
      RETURN m AS municipality, s AS subscription
      `,
    );

    if (result.records.length === 0) {
      return res.json({
        found: false,
        active: false,
        message: 'Nessun Comune EasyTour ha coordinate registrate.',
      });
    }

    const municipalities = result.records.map((record) => {
      const municipality = normalizeMunicipality(record);

      const distanceKm = calculateDistanceKm(
        lat,
        lng,
        municipality.latitudine,
        municipality.longitudine,
      );

      return {
        ...municipality,
        distanceKm,
      };
    });

    municipalities.sort((a, b) => a.distanceKm - b.distanceKm);

    const nearestMunicipality = municipalities[0];

    /*
      Soglia prototipo:
      se il punto selezionato è entro 8 km dal centro del Comune,
      lo consideriamo appartenente a quel Comune.

      Puoi aumentare a 10/12 km per Comuni più grandi.
      Per Roma conviene almeno 20/25 km.
    */
    const maxDistanceFromMunicipalityCenterKm =
      nearestMunicipality.nome === 'Roma' ? 25 : 8;

    if (
      nearestMunicipality.distanceKm >
      maxDistanceFromMunicipalityCenterKm
    ) {
      return res.json({
        found: false,
        active: false,
        detectedMunicipalityName: null,
        nearestMunicipalityName: nearestMunicipality.nome,
        nearestDistanceKm: Number(
          nearestMunicipality.distanceKm.toFixed(2),
        ),
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
        : `Il punto selezionato rientra nell'area del Comune di ${nearestMunicipality.nome}, ma il Comune non ha un abbonamento attivo.`,
    });
  } catch (error) {
    console.error('Errore check-point Comune:', error);

    return res.status(500).json({
      message: 'Errore nel controllo del punto selezionato',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

router.get('/:municipalityId/status', async (req, res) => {
  const { municipalityId } = req.params;

  const session = driver.session();

  try {
    const result = await session.run(
      `
      MATCH (m:Municipality {id: $municipalityId})
      OPTIONAL MATCH (m)-[:HAS_SUBSCRIPTION]->(s:Subscription)
      RETURN m AS municipality, s AS subscription
      LIMIT 1
      `,
      {
        municipalityId,
      },
    );

    if (result.records.length === 0) {
      return res.status(404).json({
        found: false,
        active: false,
        message: 'Comune non trovato',
      });
    }

    const municipality = normalizeMunicipality(result.records[0]);

    return res.json({
      found: true,
      ...municipality,
      message: municipality.active
        ? 'Comune attivo'
        : 'Comune non attivo',
    });
  } catch (error) {
    console.error('Errore stato Comune:', error);

    return res.status(500).json({
      message: 'Errore nella verifica del Comune',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

module.exports = router;