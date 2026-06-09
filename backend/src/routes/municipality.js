const express = require("express");
const { driver } = require("../db");

const router = express.Router();

router.get("/:municipalityId/status", async (req, res) => {
  const { municipalityId } = req.params;
  const session = driver.session();

  try {
    const result = await session.run(
      `
      MATCH (m:Municipality {id: $municipalityId})
      OPTIONAL MATCH (m)-[:HAS_SUBSCRIPTION]->(s:Subscription)
      RETURN
        m.id AS id,
        m.nome AS nome,
        m.statoServizio AS statoServizio,
        s.stato AS statoAbbonamento
      `,
      { municipalityId }
    );

    if (result.records.length === 0) {
      return res.json({
        active: false,
        message: "Comune non registrato"
      });
    }

    const record = result.records[0];

    const active =
      record.get("statoServizio") === "ATTIVO" &&
      record.get("statoAbbonamento") === "ATTIVO";

    res.json({
      id: record.get("id"),
      nome: record.get("nome"),
      active,
      statoServizio: record.get("statoServizio"),
      statoAbbonamento: record.get("statoAbbonamento")
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({
      error: "Errore nella verifica del Comune"
    });
  } finally {
    await session.close();
  }
});

module.exports = router;