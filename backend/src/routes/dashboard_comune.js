const express = require('express');
const router = express.Router();

const { driver } = require('../db');
const { verifyToken, requireRole } = require('../middleware/auth');

/*
  Dashboard comunale (RF-C1..C7).
  Tutte le route sono protette: solo un OPERATORE_COMUNALE autenticato
  può accedere ai dati aggregati DEL PROPRIO Comune.

  Il Comune dell'operatore viene ricavato dalla relazione
  (User)-[:MANAGES]->(Municipality), a partire dallo userId del token.
*/

// Converte gli interi Neo4j ({low, high}) in numeri JS semplici.
function toNum(value) {
  if (value === null || value === undefined) return 0;
  if (typeof value === 'number') return value;
  if (typeof value === 'object' && value.low !== undefined) return value.low;
  return Number(value) || 0;
}

// Tutte le route della dashboard richiedono operatore autenticato.
router.use(verifyToken, requireRole('OPERATORE_COMUNALE'));

/*
  Recupera l'id del Comune gestito dall'operatore loggato.
  Restituisce null se l'operatore non gestisce alcun Comune.
*/
async function getMunicipalityId(session, userId) {
  const result = await session.run(
    `
    MATCH (u:User {id: $userId})-[:MANAGES]->(m:Municipality)
    RETURN m.id AS municipalityId
    LIMIT 1
    `,
    { userId }
  );
  if (result.records.length === 0) return null;
  return result.records[0].get('municipalityId');
}

/*
  GET /dashboard/summary
  Card in alto (RF-C2): totale itinerari salvati, numero luoghi distinti
  presenti negli itinerari, numero "hidden gems" (luoghi poco presenti),
  numero segnalazioni (per ora 0, in attesa del nodo Report di Andrea).
*/
router.get('/summary', async (req, res) => {
  const session = driver.session({ database: process.env.NEO4J_DATABASE });
  try {
    const municipalityId = await getMunicipalityId(session, req.user.userId);
    if (!municipalityId) {
      return res.status(404).json({ message: 'Nessun Comune associato' });
    }

    const result = await session.run(
      `
      MATCH (i:Itinerary)-[:ASSOCIATED_TO]->(m:Municipality {id: $municipalityId})
      WITH count(DISTINCT i) AS totItinerari, collect(DISTINCT i) AS itinerari
      OPTIONAL MATCH (i2:Itinerary)-[:ASSOCIATED_TO]->(:Municipality {id: $municipalityId}),
                     (i2)-[:HAS_STOP]->(:ItineraryStop)-[:REFERS_TO]->(p:Place)
      RETURN totItinerari, count(DISTINCT p) AS luoghiPresenti
      `,
      { municipalityId }
    );

    const totItinerari = toNum(result.records[0]?.get('totItinerari'));
    const luoghiPresenti = toNum(result.records[0]?.get('luoghiPresenti'));

    res.json({
      itinerariSalvati: totItinerari,
      luoghiPiuPresenti: luoghiPresenti,
      hiddenGems: 0, // calcolato a parte da /places-to-improve se serve
      segnalazioni: 0, // in attesa del nodo Report (Andrea)
    });
  } catch (error) {
    console.error('Errore /summary:', error);
    res.status(500).json({ message: 'Errore', error: error.message });
  } finally {
    await session.close();
  }
});

/*
  GET /dashboard/top-places
  RF-C3: luoghi più presenti negli itinerari salvati del Comune,
  ordinati per numero di presenze (tappe che vi fanno riferimento).
*/
router.get('/top-places', async (req, res) => {
  const session = driver.session({ database: process.env.NEO4J_DATABASE });
  try {
    const municipalityId = await getMunicipalityId(session, req.user.userId);
    if (!municipalityId) {
      return res.status(404).json({ message: 'Nessun Comune associato' });
    }

    const result = await session.run(
      `
      MATCH (i:Itinerary)-[:ASSOCIATED_TO]->(:Municipality {id: $municipalityId})
      MATCH (i)-[:HAS_STOP]->(:ItineraryStop)-[:REFERS_TO]->(p:Place)
      WITH p, count(*) AS presenze
      RETURN p.id AS id, p.nome AS nome, p.immagineUrl AS immagineUrl,
             p.rating AS rating, presenze
      ORDER BY presenze DESC
      LIMIT 10
      `,
      { municipalityId }
    );

    const luoghi = result.records.map((r) => ({
      id: r.get('id'),
      nome: r.get('nome'),
      immagineUrl: r.get('immagineUrl'),
      rating: r.get('rating'),
      presenze: toNum(r.get('presenze')),
    }));

    res.json(luoghi);
  } catch (error) {
    console.error('Errore /top-places:', error);
    res.status(500).json({ message: 'Errore', error: error.message });
  } finally {
    await session.close();
  }
});

/*
  GET /dashboard/places-to-improve
  RF-C4: luoghi da valorizzare = poco presenti negli itinerari ma con
  rating alto ("poche presenze, alto gradimento", come nel mock-up).
*/
router.get('/places-to-improve', async (req, res) => {
  const session = driver.session({ database: process.env.NEO4J_DATABASE });
  try {
    const municipalityId = await getMunicipalityId(session, req.user.userId);
    if (!municipalityId) {
      return res.status(404).json({ message: 'Nessun Comune associato' });
    }

    // Conta le presenze di ogni Place negli itinerari del Comune.
    // Include anche i Place con 0 presenze (mai inseriti in itinerari),
    // ordina per presenze crescenti e rating decrescente.
    const result = await session.run(
      `
      MATCH (i:Itinerary)-[:ASSOCIATED_TO]->(:Municipality {id: $municipalityId})
      MATCH (i)-[:HAS_STOP]->(:ItineraryStop)-[:REFERS_TO]->(p:Place)
      WHERE p.rating IS NOT NULL
      WITH p, count(*) AS presenze
      RETURN p.id AS id, p.nome AS nome, p.immagineUrl AS immagineUrl,
             p.rating AS rating, presenze
      ORDER BY presenze ASC, p.rating DESC
      LIMIT 10
      `,
      { municipalityId }
    );

    const luoghi = result.records.map((r) => ({
      id: r.get('id'),
      nome: r.get('nome'),
      immagineUrl: r.get('immagineUrl'),
      rating: r.get('rating'),
      presenze: toNum(r.get('presenze')),
    }));

    res.json(luoghi);
  } catch (error) {
    console.error('Errore /places-to-improve:', error);
    res.status(500).json({ message: 'Errore', error: error.message });
  } finally {
    await session.close();
  }
});

/*
  GET /dashboard/filters
  RF-C5: distribuzione dei filtri usati negli itinerari del Comune.
  I valori null e "none" vengono normalizzati come "Tutti".
*/
router.get('/filters', async (req, res) => {
  const session = driver.session({ database: process.env.NEO4J_DATABASE });

  try {
    const municipalityId = await getMunicipalityId(session, req.user.userId);

    if (!municipalityId) {
      return res.status(404).json({ message: 'Nessun Comune associato' });
    }

    const result = await session.run(
      `
      MATCH (i:Itinerary)-[:ASSOCIATED_TO]->(m:Municipality {id: $municipalityId})
      WITH
        CASE
          WHEN i.filterType IS NULL OR i.filterType = '' OR toLower(i.filterType) = 'none' OR toLower(i.filterType) = 'tutti' THEN 'Tutti'

          WHEN toLower(i.filterType) IN ['ho_solo_2_ore', '2 ore', 'ho solo 2 ore', 'solo 2 ore', 'two_hours'] THEN 'Ho solo 2 ore'

          WHEN toLower(i.filterType) IN ['budget_limitato', 'budget limitato', 'budget'] THEN 'Budget limitato'

          WHEN toLower(i.filterType) IN ['posti_nascosti', 'posti nascosti', 'nascosti', 'hidden gems', 'hidden'] THEN 'Posti nascosti'

          ELSE i.filterType
        END AS filtroNormalizzato,
        count(i) AS quanti

      WITH collect({
        filtro: filtroNormalizzato,
        quanti: quanti
      }) AS dati

      UNWIND ['Tutti', 'Ho solo 2 ore', 'Budget limitato', 'Posti nascosti'] AS filtroBase

      WITH filtroBase, dati,
           [d IN dati WHERE d.filtro = filtroBase | d.quanti] AS conteggi

      RETURN
        filtroBase AS filtro,
        CASE
          WHEN size(conteggi) = 0 THEN 0
          ELSE conteggi[0]
        END AS quanti

      ORDER BY
        CASE filtroBase
          WHEN 'Tutti' THEN 1
          WHEN 'Ho solo 2 ore' THEN 2
          WHEN 'Budget limitato' THEN 3
          WHEN 'Posti nascosti' THEN 4
          ELSE 5
        END
      `,
      { municipalityId }
    );

    const filtri = result.records.map((r) => ({
      filtro: r.get('filtro'),
      quanti: toNum(r.get('quanti')),
    }));

    console.log('DASHBOARD FILTERS:', filtri);

    res.json(filtri);
  } catch (error) {
    console.error('Errore /filters:', error);
    res.status(500).json({ message: 'Errore', error: error.message });
  } finally {
    await session.close();
  }
});

/*
  GET /dashboard/reports
  RF-C6: segnalazioni ricevute dal Comune.
  PLACEHOLDER: il nodo Report non esiste ancora (lo crea il flusso
  turista di Andrea). Per ora restituisce lista vuota, così il
  frontend mostra lo stato "nessuna segnalazione" senza errori.
*/
router.get('/reports', async (req, res) => {
  const session = driver.session({ database: process.env.NEO4J_DATABASE });

  try {
    const municipalityId = await getMunicipalityId(session, req.user.userId);

    console.log('DASHBOARD REPORTS - userId:', req.user.userId);
    console.log('DASHBOARD REPORTS - municipalityId:', municipalityId);

    if (!municipalityId) {
      return res.status(404).json({ message: 'Nessun Comune associato' });
    }

    const result = await session.run(
      `
      MATCH (operator:User {id: $operatorId})-[:MANAGES]->(m:Municipality)
      MATCH (r:Report)
      WHERE r.municipalityId = m.id
         OR (r)-[:FOR_MUNICIPALITY]->(m)
      OPTIONAL MATCH (u:User)-[:CREATED_REPORT]->(r)
      OPTIONAL MATCH (r)-[:ABOUT_PLACE]->(p:Place)
      RETURN
        r.id AS id,
        r.categoria AS categoria,
        r.descrizione AS descrizione,
        r.stato AS stato,
        r.fonte AS fonte,
        r.dataCreazione AS dataCreazione,
        u.id AS userId,
        coalesce(u.username, u.nome, u.email) AS username,
        u.email AS userEmail,
        p.id AS placeId,
        coalesce(p.nome, r.placeName) AS placeName,
        m.id AS municipalityId,
        m.nome AS municipalityName
      ORDER BY r.dataCreazione DESC
      `,
      {
        operatorId: req.user.userId,
      }
    );

    const reports = result.records.map((record) => ({
      id: record.get('id'),
      categoria: record.get('categoria') || 'Segnalazione',
      descrizione: record.get('descrizione') || '',
      stato: record.get('stato') || 'NUOVA',
      fonte: record.get('fonte') || 'DIARIO_VIAGGIO',
      dataCreazione: record.get('dataCreazione')?.toString() || '',
      userId: record.get('userId') || '',
      username: record.get('username') || 'Utente',
      userEmail: record.get('userEmail') || '',
      placeId: record.get('placeId') || '',
      placeName: record.get('placeName') || 'Luogo non specificato',
      municipalityId: record.get('municipalityId') || '',
      municipalityName: record.get('municipalityName') || '',
    }));

    console.log('DASHBOARD REPORTS - trovati:', reports.length);
    console.log('DASHBOARD REPORTS - dati:', reports);

    return res.json(reports);
  } catch (error) {
    console.error('Errore /reports:', error);
    return res.status(500).json({
      message: 'Errore durante il caricamento delle segnalazioni',
      error: error.message,
    });
  } finally {
    await session.close();
  }
});

module.exports = router;