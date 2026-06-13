const express = require('express');
const axios = require('axios');

const router = express.Router();

const WIKI_USER_AGENT =
  'EasyTourUniversityProject/1.0 (student project; contact: example@example.com)';

function normalizeTitle(title) {
  return encodeURIComponent(title.replaceAll(' ', '_'));
}

const wikiClient = axios.create({
  headers: {
    'User-Agent': WIKI_USER_AGENT,
    'Accept': 'application/json',
  },
});

router.get('/summary', async (req, res) => {
  const query = req.query.q;

  if (!query) {
    return res.status(400).json({
      message: 'Parametro q mancante',
    });
  }

  try {
    const searchResponse = await wikiClient.get(
      'https://it.wikipedia.org/w/api.php',
      {
        params: {
          action: 'query',
          list: 'search',
          srsearch: query,
          format: 'json',
          origin: '*',
          srlimit: 1,
        },
      },
    );

    const results = searchResponse.data?.query?.search || [];

    if (results.length === 0) {
      return res.json({
        titolo: summary.title || title,
        descrizione:
          summary.extract || 'Descrizione non disponibile da Wikipedia.',
        wikipediaUrl: summary.content_urls?.desktop?.page || null,
        immagineUrl:
          summary.thumbnail?.source ||
          summary.originalimage?.source ||
          null,
      });
    }

    const title = results[0].title;
    const encodedTitle = normalizeTitle(title);

    const summaryResponse = await wikiClient.get(
      `https://it.wikipedia.org/api/rest_v1/page/summary/${encodedTitle}`,
    );

    const summary = summaryResponse.data;

    return res.json({
      titolo: summary.title || title,
      descrizione:
        summary.extract || 'Descrizione non disponibile da Wikipedia.',
      wikipediaUrl: summary.content_urls?.desktop?.page || null,
      immagineUrl:
        summary.thumbnail?.source ||
        summary.originalimage?.source ||
        null,
    });
  } catch (error) {
    console.error(
      'Errore Wikipedia:',
      error.response?.data || error.message,
    );

    return res.status(500).json({
      message: 'Errore nel recupero descrizione Wikipedia',
      error: error.response?.data || error.message,
    });
  }
});
router.get('/images', async (req, res) => {
  const query = req.query.q;

  if (!query) {
    return res.status(400).json({
      message: 'Parametro q mancante',
    });
  }

  try {
    const searchResponse = await wikiClient.get(
      'https://it.wikipedia.org/w/api.php',
      {
        params: {
          action: 'query',
          list: 'search',
          srsearch: query,
          format: 'json',
          origin: '*',
          srlimit: 1,
        },
      },
    );

    const results = searchResponse.data?.query?.search || [];

    if (results.length === 0) {
      return res.json([]);
    }

    const title = results[0].title;

    const imagesResponse = await wikiClient.get(
      'https://it.wikipedia.org/w/api.php',
      {
        params: {
          action: 'query',
          titles: title,
          prop: 'images',
          imlimit: 20,
          format: 'json',
          origin: '*',
        },
      },
    );

    const pages = imagesResponse.data?.query?.pages || {};
    const page = Object.values(pages)[0];
    const images = page?.images || [];

    const usefulImages = images
      .map((img) => img.title)
      .filter((title) => {
        const lower = title.toLowerCase();

        return (
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp')
        ) && !lower.includes('logo') &&
          !lower.includes('icon') &&
          !lower.includes('map') &&
          !lower.includes('svg');
      })
      .slice(0, 8);

    if (usefulImages.length === 0) {
      return res.json([]);
    }

    const imageInfoResponse = await wikiClient.get(
      'https://it.wikipedia.org/w/api.php',
      {
        params: {
          action: 'query',
          titles: usefulImages.join('|'),
          prop: 'imageinfo',
          iiprop: 'url',
          format: 'json',
          origin: '*',
        },
      },
    );

    const imagePages = imageInfoResponse.data?.query?.pages || {};

    const urls = Object.values(imagePages)
      .map((imgPage) => imgPage.imageinfo?.[0]?.url)
      .filter(Boolean);

    return res.json(urls);
  } catch (error) {
    console.error(
      'Errore immagini Wikipedia:',
      error.response?.data || error.message,
    );

    return res.status(500).json({
      message: 'Errore nel recupero immagini Wikipedia',
      error: error.response?.data || error.message,
    });
  }
});
module.exports = router;