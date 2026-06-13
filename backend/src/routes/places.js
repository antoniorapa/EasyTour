const express = require('express');
const router = express.Router();

const { driver } = require('../db');

/**
 * Converte eventuali Integer Neo4j nel formato:
 * { low: ..., high: ... }
 * in un normale numero JavaScript.
 */
function neo4jNumberToJs(value) {
  if (value === null || value === undefined) return 0;

  if (typeof value === 'number') return value;

  if (typeof value === 'object' && value.low !== undefined) {
    return value.low;
  }

  const parsed = Number(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

/**
 * Normalizza un oggetto Place prima di inviarlo al frontend.
 */
function normalizePlace(place) {
  return {
    id: place.id,
    nome: place.nome,
    latitudine: Number(place.latitudine),
    longitudine: Number(place.longitudine),
    rating: Number(place.rating),
    numeroRecensioni: neo4jNumberToJs(place.numeroRecensioni),
    descrizione: place.descrizione,
    immagineUrl: place.immagineUrl,
    categoria: place.categoria,
    comune: place.comune,
    distanzaKm:
      place.distanzaKm !== undefined && place.distanzaKm !== null
        ? Number(place.distanzaKm)
        : undefined,
  };
}

/**
 * Coordinate demo del centro dei Comuni.
 * Per ora abbiamo configurato solo Salerno.
 * Più avanti queste coordinate potranno essere salvate direttamente nel nodo Municipality.
 */
const municipalityCenters = {
  comune_salerno: {
    latitudine: 40.6824,
    longitudine: 14.7681,
  },
};

/**
 * GET /places/search/free?q=...
 * Ricerca libera tra tutte le attrazioni presenti in Neo4j,
 * senza vincoli di Comune, raggio o filtro.
 *
 * Esempio:
 * /places/search/free?q=duomo
 */
router.get('/search/free', async (req, res) => {
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  const queryText = (req.query.q || '').toString().trim();

  if (queryText.length < 2) {
    await session.close();
    return res.json([]);
  }

  try {
    const result = await session.run(
      `
      MATCH (p:Place)
      WHERE toLower(p.nome) CONTAINS toLower($queryText)
         OR toLower(p.categoria) CONTAINS toLower($queryText)
         OR toLower(p.descrizione) CONTAINS toLower($queryText)
      OPTIONAL MATCH (p)-[:LOCATED_IN]->(m:Municipality)
      RETURN p {
        .id,
        .nome,
        .latitudine,
        .longitudine,
        .rating,
        .numeroRecensioni,
        .descrizione,
        .immagineUrl,
        .categoria,
        comune: m.nome
      } AS place
      ORDER BY p.rating DESC, p.numeroRecensioni DESC
      LIMIT 10
      `,
      {
        queryText,
      }
    );

    const places = result.records.map((record) =>
      normalizePlace(record.get('place'))
    );

    res.json(places);
  } catch (error) {
    console.error('Errore ricerca libera luoghi:', error);

    res.status(500).json({
      message: 'Errore nella ricerca libera dei luoghi',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

/**
 * GET /places/:municipalityId/radius/:radiusKm
 * Restituisce le attrazioni di un Comune entro un certo raggio.
 *
 * Esempio:
 * GET /places/comune_salerno/radius/1
 */
router.get('/:municipalityId/radius/:radiusKm', async (req, res) => {
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  const { municipalityId, radiusKm } = req.params;
  const radius = Number(radiusKm);

  if (Number.isNaN(radius) || radius <= 0) {
    await session.close();

    return res.status(400).json({
      message: 'Raggio non valido',
    });
  }

  const center = municipalityCenters[municipalityId];

  if (!center) {
    await session.close();

    return res.status(404).json({
      message: 'Centro geografico del Comune non configurato',
    });
  }

  try {
    const result = await session.run(
      `
      MATCH (p:Place)-[:LOCATED_IN]->(:Municipality {id: $municipalityId})
      WITH p,
           point({
             latitude: $centerLat,
             longitude: $centerLon
           }) AS centerPoint,
           point({
             latitude: toFloat(p.latitudine),
             longitude: toFloat(p.longitudine)
           }) AS placePoint
      WITH p, point.distance(centerPoint, placePoint) / 1000 AS distanzaKm
      WHERE distanzaKm <= $radius
      RETURN p {
        .id,
        .nome,
        .latitudine,
        .longitudine,
        .rating,
        .numeroRecensioni,
        .descrizione,
        .immagineUrl,
        .categoria,
        distanzaKm: distanzaKm
      } AS place
      ORDER BY distanzaKm ASC, p.rating DESC
      `,
      {
        municipalityId,
        radius,
        centerLat: center.latitudine,
        centerLon: center.longitudine,
      }
    );

    const places = result.records.map((record) => {
      const place = record.get('place');

      return normalizePlace({
        ...place,
        distanzaKm: Math.round(Number(place.distanzaKm) * 100) / 100,
      });
    });

    res.json(places);
  } catch (error) {
    console.error('Errore ricerca luoghi per raggio:', error);

    res.status(500).json({
      message: 'Errore nella ricerca dei luoghi per raggio',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

/**
 * GET /places/:municipalityId/radius/:radiusKm/filter/:filterType
 * Restituisce le attrazioni filtrate rispettando anche il raggio selezionato.
 *
 * Esempi:
 * /places/comune_salerno/radius/3/filter/budget
 * /places/comune_salerno/radius/3/filter/two_hours
 * /places/comune_salerno/radius/3/filter/hidden
 */
router.get('/:municipalityId/radius/:radiusKm/filter/:filterType', async (req, res) => {
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  const { municipalityId, radiusKm, filterType } = req.params;
  const radius = Number(radiusKm);

  if (Number.isNaN(radius) || radius <= 0) {
    await session.close();

    return res.status(400).json({
      message: 'Raggio non valido',
    });
  }

  const center = municipalityCenters[municipalityId];

  if (!center) {
    await session.close();

    return res.status(404).json({
      message: 'Centro geografico del Comune non configurato',
    });
  }

  let extraWhere = '';
  let orderBy = 'ORDER BY distanzaKm ASC, p.rating DESC';
  let limit = '';

  if (filterType === 'two_hours') {
    orderBy = 'ORDER BY p.rating DESC, distanzaKm ASC';
    limit = 'LIMIT 3';
  } else if (filterType === 'budget') {
    extraWhere = 'AND p.categoria IN ["natura", "panoramico"]';
    orderBy = 'ORDER BY distanzaKm ASC, p.rating DESC';
  } else if (filterType === 'hidden') {
    orderBy = 'ORDER BY p.numeroRecensioni ASC, distanzaKm ASC';
    limit = 'LIMIT 3';
  } else {
    await session.close();

    return res.status(400).json({
      message: 'Filtro non valido',
    });
  }

  try {
    const result = await session.run(
      `
      MATCH (p:Place)-[:LOCATED_IN]->(:Municipality {id: $municipalityId})
      WITH p,
           point({
             latitude: $centerLat,
             longitude: $centerLon
           }) AS centerPoint,
           point({
             latitude: toFloat(p.latitudine),
             longitude: toFloat(p.longitudine)
           }) AS placePoint
      WITH p, point.distance(centerPoint, placePoint) / 1000 AS distanzaKm
      WHERE distanzaKm <= $radius
      ${extraWhere}
      RETURN p {
        .id,
        .nome,
        .latitudine,
        .longitudine,
        .rating,
        .numeroRecensioni,
        .descrizione,
        .immagineUrl,
        .categoria,
        distanzaKm: distanzaKm
      } AS place
      ${orderBy}
      ${limit}
      `,
      {
        municipalityId,
        radius,
        centerLat: center.latitudine,
        centerLon: center.longitudine,
      }
    );

    const places = result.records.map((record) => {
      const place = record.get('place');

      return normalizePlace({
        ...place,
        distanzaKm: Math.round(Number(place.distanzaKm) * 100) / 100,
      });
    });

    res.json(places);
  } catch (error) {
    console.error('Errore filtro luoghi per raggio:', error);

    res.status(500).json({
      message: 'Errore nell’applicazione del filtro per raggio',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

/**
 * GET /places/:municipalityId/filter/:filterType
 * Restituisce le attrazioni filtrate di un Comune.
 * Questa route rimane utile se vuoi filtrare senza raggio.
 */
router.get('/:municipalityId/filter/:filterType', async (req, res) => {
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  const { municipalityId, filterType } = req.params;

  let query = '';

  if (filterType === 'two_hours') {
    query = `
      MATCH (p:Place)-[:LOCATED_IN]->(:Municipality {id: $municipalityId})
      RETURN p {
        .id,
        .nome,
        .latitudine,
        .longitudine,
        .rating,
        .numeroRecensioni,
        .descrizione,
        .immagineUrl,
        .categoria
      } AS place
      ORDER BY p.rating DESC
      LIMIT 3
    `;
  } else if (filterType === 'budget') {
    query = `
      MATCH (p:Place)-[:LOCATED_IN]->(:Municipality {id: $municipalityId})
      WHERE p.categoria IN ["natura", "panoramico"]
      RETURN p {
        .id,
        .nome,
        .latitudine,
        .longitudine,
        .rating,
        .numeroRecensioni,
        .descrizione,
        .immagineUrl,
        .categoria
      } AS place
      ORDER BY p.rating DESC
    `;
  } else if (filterType === 'hidden') {
    query = `
      MATCH (p:Place)-[:LOCATED_IN]->(:Municipality {id: $municipalityId})
      RETURN p {
        .id,
        .nome,
        .latitudine,
        .longitudine,
        .rating,
        .numeroRecensioni,
        .descrizione,
        .immagineUrl,
        .categoria
      } AS place
      ORDER BY p.numeroRecensioni ASC, p.rating DESC
      LIMIT 3
    `;
  } else {
    await session.close();

    return res.status(400).json({
      message: 'Filtro non valido',
    });
  }

  try {
    const result = await session.run(query, {
      municipalityId,
    });

    const places = result.records.map((record) =>
      normalizePlace(record.get('place'))
    );

    res.json(places);
  } catch (error) {
    console.error('Errore filtro luoghi:', error);

    res.status(500).json({
      message: 'Errore nell’applicazione del filtro',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

/**
 * GET /places/detail/:placeId
 * Restituisce il dettaglio di una singola attrazione.
 *
 * Esempio:
 * GET /places/detail/place_duomo_salerno
 */
router.get('/detail/:placeId', async (req, res) => {
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  const { placeId } = req.params;

  try {
    const result = await session.run(
      `
      MATCH (p:Place {id: $placeId})-[:LOCATED_IN]->(m:Municipality)
      RETURN p {
        .id,
        .nome,
        .latitudine,
        .longitudine,
        .rating,
        .numeroRecensioni,
        .descrizione,
        .immagineUrl,
        .categoria,
        comune: m.nome,
        municipality: m {
          .id,
          .nome,
          .provincia,
          .regione
        }
      } AS place
      `,
      {
        placeId,
      }
    );

    if (result.records.length === 0) {
      return res.status(404).json({
        message: 'Attrazione non trovata',
      });
    }

    const place = normalizePlace(result.records[0].get('place'));

    res.json(place);
  } catch (error) {
    console.error('Errore dettaglio luogo:', error);

    res.status(500).json({
      message: 'Errore nel recupero del dettaglio luogo',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

/**
 * GET /places/:municipalityId
 * Restituisce tutte le attrazioni di un Comune.
 *
 * Questa route deve stare dopo le route più specifiche,
 * altrimenti rischia di intercettarle.
 */
router.get('/:municipalityId', async (req, res) => {
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  const { municipalityId } = req.params;

  try {
    const result = await session.run(
      `
      MATCH (p:Place)-[:LOCATED_IN]->(:Municipality {id: $municipalityId})
      RETURN p {
        .id,
        .nome,
        .latitudine,
        .longitudine,
        .rating,
        .numeroRecensioni,
        .descrizione,
        .immagineUrl,
        .categoria
      } AS place
      ORDER BY p.rating DESC
      `,
      {
        municipalityId,
      }
    );

    const places = result.records.map((record) =>
      normalizePlace(record.get('place'))
    );

    res.json(places);
  } catch (error) {
    console.error('Errore recupero luoghi:', error);

    res.status(500).json({
      message: 'Errore nel recupero dei luoghi',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

module.exports = router;