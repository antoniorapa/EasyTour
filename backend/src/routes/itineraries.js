const express = require('express');
const router = express.Router();

const { driver } = require('../db');

function neo4jNumberToJs(value) {
  if (value === null || value === undefined) return 0;
  if (typeof value === 'number') return value;

  if (typeof value === 'object' && value.low !== undefined) {
    return value.low;
  }

  const parsed = Number(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

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
  };
}

function toRadians(degrees) {
  return degrees * Math.PI / 180;
}

function calculateDistanceKm(pointA, pointB) {
  const earthRadiusKm = 6371;

  const dLat = toRadians(pointB.latitudine - pointA.latitudine);
  const dLon = toRadians(pointB.longitudine - pointA.longitudine);

  const lat1 = toRadians(pointA.latitudine);
  const lat2 = toRadians(pointB.latitudine);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLon / 2) * Math.sin(dLon / 2) *
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
  // Stima semplice: 1 km a piedi ≈ 12 minuti.
  return Math.round(distanceKm * 12);
}

function estimateVisitTimeMinutes(place) {
  if (place.categoria === 'storico') return 50;
  if (place.categoria === 'natura') return 40;
  if (place.categoria === 'panoramico') return 35;

  return 40;
}

function distributeStopsByDays(orderedStops, numeroGiorni) {
  return orderedStops.map((stop, index) => {
    const giorno = Math.floor(index * numeroGiorni / orderedStops.length) + 1;

    return {
      ...stop,
      giorno,
    };
  });
}

/**
 * POST /itineraries/generate
 * Genera un itinerario usando una logica Nearest Neighbor semplificata.
 */
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
      message: 'Lista attrazioni non valida',
    });
  }

  const parsedNumeroGiorni = Number(numeroGiorni) > 0
    ? Number(numeroGiorni)
    : 1;

  // Centro demo di Salerno.
  // Più avanti potrà arrivare dal nodo Municipality.
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
        .categoria
      } AS place
      `,
      {
        placeIds,
      }
    );

    const places = result.records.map((record) =>
      normalizePlace(record.get('place'))
    );

    if (places.length === 0) {
      return res.status(404).json({
        message: 'Nessuna attrazione trovata per generare itinerario',
      });
    }

    const orderedPlaces = orderPlacesWithNearestNeighbor(places, startPoint);

    const stopsBeforeDays = orderedPlaces.map((item, index) => {
      const tempoArrivoStimato = index === 0
        ? estimateArrivalTimeMinutes(item.distanzaDalPuntoPrecedenteKm)
        : estimateArrivalTimeMinutes(item.distanzaDalPuntoPrecedenteKm);

      const tempoVisitaStimato = estimateVisitTimeMinutes(item.place);

      return {
        ordine: index + 1,
        giorno: 1,
        tempoVisitaStimato,
        tempoArrivoStimato,
        distanzaDalPuntoPrecedenteKm: item.distanzaDalPuntoPrecedenteKm,
        place: item.place,
      };
    });

    const stops = distributeStopsByDays(stopsBeforeDays, parsedNumeroGiorni);

    const durataStimataMinuti = stops.reduce(
      (total, stop) =>
        total + stop.tempoVisitaStimato + stop.tempoArrivoStimato,
      0
    );

    res.json({
      filterType,
      numeroGiorni: parsedNumeroGiorni,
      durataStimataMinuti,
      criterioOrdinamento: 'nearest_neighbor_semplificato',
      stops,
    });
  } catch (error) {
    console.error('Errore generazione itinerario:', error);

    res.status(500).json({
      message: 'Errore nella generazione dell’itinerario',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

/**
 * POST /itineraries/save
 * Salva un itinerario generato/modificato su Neo4j.
 */
router.post('/save', async (req, res) => {
  const session = driver.session({
    database: process.env.NEO4J_DATABASE,
  });

  const {
    userId,
    municipalityId,
    titolo,
    filterType = 'none',
    numeroGiorni = 1,
    stops,
  } = req.body;

  if (!userId || !municipalityId || !Array.isArray(stops) || stops.length === 0) {
    await session.close();

    return res.status(400).json({
      message: 'Dati itinerario non validi',
    });
  }

  const itineraryId = `itinerary_${Date.now()}`;

  try {
    await session.run(
      `
      MATCH (u:User {id: $userId})
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

      const placeId = stop.place?.id || stop.placeId;

      if (!placeId) {
        continue;
      }

      await session.run(
        `
        MATCH (i:Itinerary {id: $itineraryId})
        MATCH (p:Place {id: $placeId})
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

    res.status(201).json({
      message: 'Itinerario salvato correttamente',
      itineraryId,
    });
  } catch (error) {
    console.error('Errore salvataggio itinerario:', error);

    res.status(500).json({
      message: 'Errore nel salvataggio dell’itinerario',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

module.exports = router;