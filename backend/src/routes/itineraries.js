const express = require("express");
const { driver } = require("../db");

const router = express.Router();

/**
 * Generazione itinerario.
 * Per ora usa una logica semplice:
 * riceve una lista di placeIds e li restituisce ordinati per rating.
 * In seguito puoi sostituire questa parte con Nearest Neighbor.
 */
router.post("/generate", async (req, res) => {
  const { placeIds, filterType, numeroGiorni = 1 } = req.body;

  if (!placeIds || !Array.isArray(placeIds) || placeIds.length === 0) {
    return res.status(400).json({
      error: "Devi fornire una lista di placeIds"
    });
  }

  const session = driver.session();

  try {
    const result = await session.run(
      `
      MATCH (p:Place)
      WHERE p.id IN $placeIds
      RETURN
        p.id AS id,
        p.nome AS nome,
        p.latitudine AS latitudine,
        p.longitudine AS longitudine,
        p.rating AS rating,
        p.numeroRecensioni AS numeroRecensioni,
        p.descrizione AS descrizione,
        p.immagineUrl AS immagineUrl,
        p.categoria AS categoria
      ORDER BY p.rating DESC
      `,
      { placeIds }
    );

    const places = result.records.map((record, index) => ({
      ordine: index + 1,
      giorno: numeroGiorni > 1 ? Math.floor(index / Math.ceil(result.records.length / numeroGiorni)) + 1 : 1,
      tempoVisitaStimato: 45,
      tempoArrivoStimato: index === 0 ? 0 : 15,
      place: {
        id: record.get("id"),
        nome: record.get("nome"),
        latitudine: record.get("latitudine"),
        longitudine: record.get("longitudine"),
        rating: record.get("rating"),
        numeroRecensioni: record.get("numeroRecensioni"),
        descrizione: record.get("descrizione"),
        immagineUrl: record.get("immagineUrl"),
        categoria: record.get("categoria")
      }
    }));

    res.json({
      filterType: filterType || "none",
      numeroGiorni,
      durataStimataMinuti: places.reduce(
        (sum, stop) => sum + stop.tempoVisitaStimato + stop.tempoArrivoStimato,
        0
      ),
      stops: places
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: "Errore nella generazione dell'itinerario"
    });
  } finally {
    await session.close();
  }
});

/**
 * Salvataggio itinerario definitivo.
 */
router.post("/save", async (req, res) => {
  const {
    userId,
    municipalityId,
    titolo,
    filterType = "none",
    numeroGiorni = 1,
    stops
  } = req.body;

  if (!userId || !municipalityId || !stops || !Array.isArray(stops) || stops.length === 0) {
    return res.status(400).json({
      error: "Dati insufficienti per salvare l'itinerario"
    });
  }

  const itineraryId = `itinerary_${Date.now()}`;
  const session = driver.session();

  try {
    const result = await session.executeWrite(async (tx) => {
      await tx.run(
        `
        MATCH (u:User {id: $userId})
        MATCH (m:Municipality {id: $municipalityId})
        CREATE (i:Itinerary {
          id: $itineraryId,
          titolo: $titolo,
          dataCreazione: date(),
          numeroGiorni: $numeroGiorni,
          durataStimataMinuti: $durataStimataMinuti,
          filtroUtilizzato: $filterType
        })
        CREATE (u)-[:CREATED]->(i)
        CREATE (i)-[:ASSOCIATED_TO]->(m)
        RETURN i.id AS id
        `,
        {
          userId,
          municipalityId,
          itineraryId,
          titolo: titolo || "Nuovo itinerario",
          numeroGiorni,
          durataStimataMinuti: stops.reduce(
            (sum, stop) =>
              sum + (stop.tempoVisitaStimato || 0) + (stop.tempoArrivoStimato || 0),
            0
          ),
          filterType
        }
      );

      for (let index = 0; index < stops.length; index++) {
        const stop = stops[index];
        const stopId = `stop_${Date.now()}_${index}`;

        await tx.run(
          `
          MATCH (i:Itinerary {id: $itineraryId})
          MATCH (p:Place {id: $placeId})
          CREATE (s:ItineraryStop {
            id: $stopId,
            ordine: $ordine,
            giorno: $giorno,
            tempoVisitaStimato: $tempoVisitaStimato,
            tempoArrivoStimato: $tempoArrivoStimato
          })
          CREATE (i)-[:HAS_STOP]->(s)
          CREATE (s)-[:REFERS_TO]->(p)
          `,
          {
            itineraryId,
            stopId,
            placeId: stop.place.id,
            ordine: stop.ordine || index + 1,
            giorno: stop.giorno || 1,
            tempoVisitaStimato: stop.tempoVisitaStimato || 45,
            tempoArrivoStimato: stop.tempoArrivoStimato || (index === 0 ? 0 : 15)
          }
        );
      }

      return {
        itineraryId
      };
    });

    res.status(201).json({
      message: "Itinerario salvato correttamente",
      itineraryId: result.itineraryId
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: "Errore nel salvataggio dell'itinerario"
    });
  } finally {
    await session.close();
  }
});

module.exports = router;