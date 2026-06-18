const express = require('express');
const router = express.Router();

const { driver } = require('../db');

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

function neo4jNumberToJs(value) {
  if (value === null || value === undefined) return 0;
  if (typeof value === 'number') return value;

  if (typeof value === 'object') {
    if (typeof value.toNumber === 'function') {
      return value.toNumber();
    }

    if (value.low !== undefined) {
      return value.low;
    }
  }

  const parsed = Number(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function neo4jDateToString(value) {
  if (!value) {
    return new Date().toISOString();
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (typeof value === 'string') {
    return value;
  }

  if (typeof value.toString === 'function') {
    return value.toString();
  }

  return new Date().toISOString();
}

function normalizePlace(place = {}) {
  return {
    id: place.id || '',
    nome: place.nome || 'Luogo senza nome',
    latitudine: Number(place.latitudine || 0),
    longitudine: Number(place.longitudine || 0),
    rating: Number(place.rating || 0),
    numeroRecensioni: neo4jNumberToJs(place.numeroRecensioni),
    descrizione: place.descrizione || '',
    immagineUrl: place.immagineUrl || '',
    categoria: place.categoria || '',
    photoReference: place.photoReference || '',
    photoName: place.photoName || '',
    googlePlaceId: place.googlePlaceId || '',
  };
}

function normalizeStop(stop = {}, place = {}) {
  return {
    id: stop.id || '',
    ordine: neo4jNumberToJs(stop.ordine),
    giorno: neo4jNumberToJs(stop.giorno) || 1,
    tempoVisitaStimato: neo4jNumberToJs(stop.tempoVisitaStimato),
    tempoArrivoStimato: neo4jNumberToJs(stop.tempoArrivoStimato),
    tempoPausaStimato: neo4jNumberToJs(stop.tempoPausaStimato),
    distanzaDalPuntoPrecedenteKm: Number(stop.distanzaDalPuntoPrecedenteKm || 0),
    place: normalizePlace(place),
  };
}

function normalizeFilter(filterType) {
  if (!filterType || filterType === 'none') return null;

  switch (filterType) {
    case 'two_hours':
      return 'Ho solo 2 ore';
    case 'budget':
      return 'Budget limitato';
    case 'hidden':
      return 'Posti nascosti';
    default:
      return filterType;
  }
}

function toRadians(degrees) {
  return (degrees * Math.PI) / 180;
}

function calculateDistanceKm(pointA, pointB) {
  const earthRadiusKm = 6371;

  const dLat = toRadians(Number(pointB.latitudine) - Number(pointA.latitudine));
  const dLon = toRadians(Number(pointB.longitudine) - Number(pointA.longitudine));

  const lat1 = toRadians(Number(pointA.latitudine));
  const lat2 = toRadians(Number(pointB.latitudine));

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLon / 2) *
      Math.sin(dLon / 2) *
      Math.cos(lat1) *
      Math.cos(lat2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return earthRadiusKm * c;
}

function orderPlacesWithNearestNeighbor(places, startPoint) {
  const remaining = [...places];
  const ordered = [];
  let currentPoint = startPoint;

  while (remaining.length > 0) {
    let nearestIndex = 0;
    let nearestDistance = calculateDistanceKm(currentPoint, remaining[0]);

    for (let i = 1; i < remaining.length; i++) {
      const distance = calculateDistanceKm(currentPoint, remaining[i]);

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }

    const [nearestPlace] = remaining.splice(nearestIndex, 1);

    ordered.push({
      place: nearestPlace,
      distanzaDalPuntoPrecedenteKm: Math.round(nearestDistance * 100) / 100,
    });

    currentPoint = {
      latitudine: nearestPlace.latitudine,
      longitudine: nearestPlace.longitudine,
    };
  }

  return ordered;
}

function estimateArrivalTimeMinutes(distanceKm) {
  if (!distanceKm || distanceKm <= 0) return 0;
  return Math.max(5, Math.round(distanceKm * 12));
}

function estimateVisitTimeMinutes(place) {
  const categoria = (place.categoria || '').toString().toLowerCase();

  if (
    categoria.includes('museum') ||
    categoria.includes('museo') ||
    categoria.includes('castello') ||
    categoria.includes('castle')
  ) {
    return 60;
  }

  if (
    categoria.includes('chiesa') ||
    categoria.includes('church') ||
    categoria.includes('storico') ||
    categoria.includes('historic') ||
    categoria.includes('landmark')
  ) {
    return 45;
  }

  if (
    categoria.includes('park') ||
    categoria.includes('parco') ||
    categoria.includes('garden') ||
    categoria.includes('natura') ||
    categoria.includes('panoramico')
  ) {
    return 40;
  }

  return 40;
}

function distributeStopsByDays(orderedStops, numeroGiorni) {
  if (!orderedStops.length) return [];

  return orderedStops.map((stop, index) => {
    const giorno = Math.floor((index * numeroGiorni) / orderedStops.length) + 1;

    return {
      ...stop,
      giorno,
    };
  });
}

function buildItineraryResponse(records) {
  const itinerariesMap = new Map();

  records.forEach((record) => {
    const userNode = record.get('u');
    const itineraryNode = record.get('i');
    const municipalityNode = record.get('m');
    const stopNode = record.get('s');
    const placeNode = record.get('p');

    if (!itineraryNode) return;

    const user = userNode ? userNode.properties : null;
    const itinerary = itineraryNode.properties;
    const municipality = municipalityNode ? municipalityNode.properties : null;
    const itineraryId = itinerary.id;

    if (!itinerariesMap.has(itineraryId)) {
      itinerariesMap.set(itineraryId, {
        id: itinerary.id,
        title: itinerary.titolo || 'Itinerario EasyTour',
        titolo: itinerary.titolo || 'Itinerario EasyTour',

        municipality:
          municipality?.nome ||
          itinerary.municipalityName ||
          itinerary.comune ||
          'Comune non disponibile',
        municipalityId: municipality?.id || itinerary.municipalityId || null,

        days: neo4jNumberToJs(itinerary.numeroGiorni) || 1,
        numeroGiorni: neo4jNumberToJs(itinerary.numeroGiorni) || 1,

        filter: normalizeFilter(itinerary.filterType),
        filterType: itinerary.filterType || 'none',

        createdAt: neo4jDateToString(itinerary.dataCreazione || itinerary.createdAt),
        dataCreazione: neo4jDateToString(itinerary.dataCreazione || itinerary.createdAt),

        stato: itinerary.stato || 'SALVATO',

        userId: user?.id || null,
        username: user?.nome || user?.email || null,
        userEmail: user?.email || null,

        stops: [],
      });
    }

    if (stopNode && placeNode) {
      const stop = stopNode.properties;
      const place = placeNode.properties;

      itinerariesMap.get(itineraryId).stops.push(
        normalizeStop(stop, place)
      );
    }
  });

  return Array.from(itinerariesMap.values()).map((itinerary) => {
    itinerary.stops.sort((a, b) => {
      if (a.giorno !== b.giorno) return a.giorno - b.giorno;
      return a.ordine - b.ordine;
    });

    return {
      ...itinerary,
      stopsCount: itinerary.stops.length,
    };
  });
}

// ─────────────────────────────────────────────────────────────
// GET /itineraries/ping
// Test per verificare che il file rotte sia montato
// ─────────────────────────────────────────────────────────────

router.get('/ping', (req, res) => {
  res.json({
    success: true,
    message: 'Rotte itineraries attive',
    endpoints: [
      'POST /itineraries/generate',
      'POST /itineraries/save',
      'GET /itineraries/user/:userId',
      'GET /itineraries/:itineraryId',
    ],
  });
});

// ─────────────────────────────────────────────────────────────
// GET /itineraries/user/:userId
// Recupera tutti gli itinerari salvati da uno specifico utente
// ─────────────────────────────────────────────────────────────

router.get('/user/:userId', async (req, res) => {
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  const { userId } = req.params;

  if (!userId) {
    await session.close();

    return res.status(400).json({
      success: false,
      message: 'UserId mancante',
    });
  }

  try {
    const result = await session.run(
      `
      MATCH (u:User {id: $userId})-[:CREATED]->(i:Itinerary)
      OPTIONAL MATCH (i)-[:ASSOCIATED_TO]->(m:Municipality)
      OPTIONAL MATCH (i)-[:HAS_STOP]->(s:ItineraryStop)-[:REFERS_TO]->(p:Place)
      RETURN u, i, m, s, p
      ORDER BY i.dataCreazione DESC, s.giorno ASC, s.ordine ASC
      `,
      { userId }
    );

    const itineraries = buildItineraryResponse(result.records);

    return res.json({
      success: true,
      userId,
      count: itineraries.length,
      itineraries,
    });
  } catch (error) {
    console.error('Errore recupero itinerari utente:', error);

    return res.status(500).json({
      success: false,
      message: 'Errore durante il recupero degli itinerari utente',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

// ─────────────────────────────────────────────────────────────
// GET /itineraries/:itineraryId
// Recupera un singolo itinerario con le sue tappe
// ─────────────────────────────────────────────────────────────

router.get('/:itineraryId', async (req, res) => {
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  const { itineraryId } = req.params;

  try {
    const result = await session.run(
      `
      MATCH (u:User)-[:CREATED]->(i:Itinerary {id: $itineraryId})
      OPTIONAL MATCH (i)-[:ASSOCIATED_TO]->(m:Municipality)
      OPTIONAL MATCH (i)-[:HAS_STOP]->(s:ItineraryStop)-[:REFERS_TO]->(p:Place)
      RETURN u, i, m, s, p
      ORDER BY s.giorno ASC, s.ordine ASC
      `,
      { itineraryId }
    );

    const itineraries = buildItineraryResponse(result.records);

    if (itineraries.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Itinerario non trovato',
      });
    }

    return res.json({
      success: true,
      itinerary: itineraries[0],
    });
  } catch (error) {
    console.error('Errore recupero dettaglio itinerario:', error);

    return res.status(500).json({
      success: false,
      message: 'Errore durante il recupero del dettaglio itinerario',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

// ─────────────────────────────────────────────────────────────
// POST /itineraries/generate
// Genera un itinerario usando Nearest Neighbor semplificato
// ─────────────────────────────────────────────────────────────

router.post('/generate', async (req, res) => {
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  const {
    placeIds,
    filterType = 'none',
    numeroGiorni = 1,
  } = req.body;

  if (!Array.isArray(placeIds) || placeIds.length === 0) {
    await session.close();

    return res.status(400).json({
      success: false,
      message: 'Lista attrazioni non valida',
    });
  }

  const parsedNumeroGiorni =
    Number(numeroGiorni) > 0 ? Number(numeroGiorni) : 1;

  const startPoint = {
    latitudine: 40.6824,
    longitudine: 14.7681,
  };

  try {
    const result = await session.run(
      `
      MATCH (p:Place)
      WHERE p.id IN $placeIds
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
        .photoReference,
        .photoName,
        .googlePlaceId
      } AS place
      `,
      { placeIds }
    );

    const places = result.records.map((record) =>
      normalizePlace(record.get('place'))
    );

    if (places.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Nessuna attrazione trovata per generare itinerario',
      });
    }

    const orderedPlaces = orderPlacesWithNearestNeighbor(places, startPoint);

    const stopsBeforeDays = orderedPlaces.map((item, index) => {
      const tempoArrivoStimato =
        index === 0
          ? 0
          : estimateArrivalTimeMinutes(item.distanzaDalPuntoPrecedenteKm);

      const tempoVisitaStimato = estimateVisitTimeMinutes(item.place);

      return {
        ordine: index + 1,
        giorno: 1,
        tempoVisitaStimato,
        tempoArrivoStimato,
        tempoPausaStimato: 0,
        distanzaDalPuntoPrecedenteKm: item.distanzaDalPuntoPrecedenteKm,
        place: item.place,
      };
    });

    const stops = distributeStopsByDays(stopsBeforeDays, parsedNumeroGiorni);

    const durataStimataMinuti = stops.reduce(
      (total, stop) =>
        total +
        Number(stop.tempoVisitaStimato || 0) +
        Number(stop.tempoArrivoStimato || 0) +
        Number(stop.tempoPausaStimato || 0),
      0
    );

    return res.json({
      success: true,
      filterType,
      numeroGiorni: parsedNumeroGiorni,
      durataStimataMinuti,
      criterioOrdinamento: 'nearest_neighbor_semplificato',
      stops,
    });
  } catch (error) {
    console.error('Errore generazione itinerario:', error);

    return res.status(500).json({
      success: false,
      message: 'Errore nella generazione dell’itinerario',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

// ─────────────────────────────────────────────────────────────
// POST /itineraries/save
// Salva un itinerario generato/modificato su Neo4j
// ─────────────────────────────────────────────────────────────

router.post('/save', async (req, res) => {
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  const {
    userId,
    username,
    municipalityId,
    titolo,
    filterType = 'none',
    numeroGiorni = 1,
    stops,
  } = req.body;

  if (!userId || !municipalityId || !Array.isArray(stops) || stops.length === 0) {
    await session.close();

    return res.status(400).json({
      success: false,
      message: 'Dati itinerario non validi',
      received: {
        userId,
        municipalityId,
        hasStops: Array.isArray(stops),
        stopsCount: Array.isArray(stops) ? stops.length : 0,
      },
    });
  }

  const itineraryId = `itinerary_${Date.now()}`;

  try {
    await session.run(
      `
      MERGE (u:User {id: $userId})
      ON CREATE SET
        u.nome = $username,
        u.email = "",
        u.ruolo = "TURISTA"
      ON MATCH SET
        u.nome = coalesce(u.nome, $username)

      MATCH (m:Municipality {id: $municipalityId})

      CREATE (i:Itinerary {
        id: $itineraryId,
        titolo: $titolo,
        filterType: $filterType,
        numeroGiorni: $numeroGiorni,
        dataCreazione: datetime(),
        stato: "SALVATO"
      })

      CREATE (u)-[:CREATED]->(i)
      CREATE (i)-[:ASSOCIATED_TO]->(m)
      `,
      {
        userId,
        username: username || '',
        municipalityId,
        itineraryId,
        titolo: titolo || 'Itinerario EasyTour',
        filterType,
        numeroGiorni: Number(numeroGiorni),
      }
    );

    for (let index = 0; index < stops.length; index++) {
      const stop = stops[index];
      const stopId = `stop_${Date.now()}_${index}`;

      const place = stop.place || {};
      const placeId = place.id || stop.placeId;

      if (!placeId) {
        continue;
      }

      await session.run(
        `
        MATCH (i:Itinerary {id: $itineraryId})

        MERGE (p:Place {id: $placeId})
        ON CREATE SET
          p.nome = $nome,
          p.latitudine = $latitudine,
          p.longitudine = $longitudine,
          p.rating = $rating,
          p.numeroRecensioni = $numeroRecensioni,
          p.descrizione = $descrizione,
          p.immagineUrl = $immagineUrl,
          p.categoria = $categoria,
          p.photoReference = $photoReference,
          p.photoName = $photoName,
          p.googlePlaceId = $googlePlaceId
        ON MATCH SET
          p.nome = coalesce(p.nome, $nome),
          p.latitudine = coalesce(p.latitudine, $latitudine),
          p.longitudine = coalesce(p.longitudine, $longitudine),
          p.rating = coalesce(p.rating, $rating),
          p.numeroRecensioni = coalesce(p.numeroRecensioni, $numeroRecensioni),
          p.descrizione = coalesce(p.descrizione, $descrizione),
          p.immagineUrl = coalesce(p.immagineUrl, $immagineUrl),
          p.categoria = coalesce(p.categoria, $categoria),
          p.photoReference = coalesce(p.photoReference, $photoReference),
          p.photoName = coalesce(p.photoName, $photoName),
          p.googlePlaceId = coalesce(p.googlePlaceId, $googlePlaceId)

        CREATE (s:ItineraryStop {
          id: $stopId,
          ordine: $ordine,
          giorno: $giorno,
          tempoVisitaStimato: $tempoVisitaStimato,
          tempoArrivoStimato: $tempoArrivoStimato,
          tempoPausaStimato: $tempoPausaStimato,
          distanzaDalPuntoPrecedenteKm: $distanzaDalPuntoPrecedenteKm
        })

        CREATE (i)-[:HAS_STOP]->(s)
        CREATE (s)-[:REFERS_TO]->(p)
        `,
        {
          itineraryId,
          placeId,
          stopId,

          nome: place.nome || 'Luogo senza nome',
          latitudine: Number(place.latitudine || 0),
          longitudine: Number(place.longitudine || 0),
          rating: Number(place.rating || 0),
          numeroRecensioni: Number(place.numeroRecensioni || 0),
          descrizione: place.descrizione || '',
          immagineUrl: place.immagineUrl || '',
          categoria: place.categoria || '',
          photoReference: place.photoReference || '',
          photoName: place.photoName || '',
          googlePlaceId: place.googlePlaceId || '',

          ordine: Number(stop.ordine || index + 1),
          giorno: Number(stop.giorno || 1),
          tempoVisitaStimato: Number(stop.tempoVisitaStimato || 40),
          tempoArrivoStimato: Number(stop.tempoArrivoStimato || 0),
          tempoPausaStimato: Number(stop.tempoPausaStimato || 0),
          distanzaDalPuntoPrecedenteKm: Number(
            stop.distanzaDalPuntoPrecedenteKm || 0
          ),
        }
      );
    }

    return res.status(201).json({
      success: true,
      message: 'Itinerario salvato correttamente',
      itineraryId,
    });
  } catch (error) {
    console.error('Errore salvataggio itinerario:', error);

    return res.status(500).json({
      success: false,
      message: 'Errore nel salvataggio dell’itinerario',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

module.exports = router;