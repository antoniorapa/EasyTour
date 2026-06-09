const express = require("express");
const { driver } = require("../db");

const router = express.Router();

/**
 * Recupera tutti i luoghi di un Comune.
 * Per ora usa i luoghi salvati in Neo4j.
 */
router.get("/:municipalityId", async (req, res) => {
  const { municipalityId } = req.params;
  const session = driver.session();

  try {
    const result = await session.run(
      `
      MATCH (p:Place)-[:LOCATED_IN]->(m:Municipality {id: $municipalityId})
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
      { municipalityId }
    );

    const places = result.records.map((record) => ({
      id: record.get("id"),
      nome: record.get("nome"),
      latitudine: record.get("latitudine"),
      longitudine: record.get("longitudine"),
      rating: record.get("rating"),
      numeroRecensioni: record.get("numeroRecensioni"),
      descrizione: record.get("descrizione"),
      immagineUrl: record.get("immagineUrl"),
      categoria: record.get("categoria")
    }));

    res.json(places);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: "Errore nel recupero dei luoghi"
    });
  } finally {
    await session.close();
  }
});

/**
 * Dettaglio di un luogo.
 */
router.get("/detail/:placeId", async (req, res) => {
  const { placeId } = req.params;
  const session = driver.session();

  try {
    const result = await session.run(
      `
      MATCH (p:Place {id: $placeId})-[:LOCATED_IN]->(m:Municipality)
      RETURN
        p.id AS id,
        p.nome AS nome,
        p.latitudine AS latitudine,
        p.longitudine AS longitudine,
        p.rating AS rating,
        p.numeroRecensioni AS numeroRecensioni,
        p.descrizione AS descrizione,
        p.immagineUrl AS immagineUrl,
        p.categoria AS categoria,
        m.id AS municipalityId,
        m.nome AS municipalityName
      `,
      { placeId }
    );

    if (result.records.length === 0) {
      return res.status(404).json({
        error: "Luogo non trovato"
      });
    }

    const record = result.records[0];

    res.json({
      id: record.get("id"),
      nome: record.get("nome"),
      latitudine: record.get("latitudine"),
      longitudine: record.get("longitudine"),
      rating: record.get("rating"),
      numeroRecensioni: record.get("numeroRecensioni"),
      descrizione: record.get("descrizione"),
      immagineUrl: record.get("immagineUrl"),
      categoria: record.get("categoria"),
      municipalityId: record.get("municipalityId"),
      municipalityName: record.get("municipalityName")
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: "Errore nel recupero del dettaglio luogo"
    });
  } finally {
    await session.close();
  }
});

/**
 * Filtri.
 * Per ora usiamo una logica semplice sui dati demo:
 * - hidden: luoghi con meno recensioni
 * - budget: luoghi gratuiti/natura/panoramici, per ora simulato su categoria
 * - two_hours: massimo 3 luoghi con rating alto
 */
router.get("/:municipalityId/filter/:filterType", async (req, res) => {
  const { municipalityId, filterType } = req.params;
  const session = driver.session();

  let query = "";
  const params = { municipalityId };

  if (filterType === "hidden") {
    query = `
      MATCH (p:Place)-[:LOCATED_IN]->(:Municipality {id: $municipalityId})
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
      ORDER BY p.numeroRecensioni ASC, p.rating DESC
      LIMIT 3
    `;
  } else if (filterType === "budget") {
    query = `
      MATCH (p:Place)-[:LOCATED_IN]->(:Municipality {id: $municipalityId})
      WHERE p.categoria IN ["natura", "panoramico"]
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
    `;
  } else if (filterType === "two_hours") {
    query = `
      MATCH (p:Place)-[:LOCATED_IN]->(:Municipality {id: $municipalityId})
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
      LIMIT 3
    `;
  } else {
    return res.status(400).json({
      error: "Filtro non valido. Usa: hidden, budget, two_hours"
    });
  }

  try {
    const result = await session.run(query, params);

    const places = result.records.map((record) => ({
      id: record.get("id"),
      nome: record.get("nome"),
      latitudine: record.get("latitudine"),
      longitudine: record.get("longitudine"),
      rating: record.get("rating"),
      numeroRecensioni: record.get("numeroRecensioni"),
      descrizione: record.get("descrizione"),
      immagineUrl: record.get("immagineUrl"),
      categoria: record.get("categoria")
    }));

    res.json(places);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: "Errore nell'applicazione del filtro"
    });
  } finally {
    await session.close();
  }
});

module.exports = router;