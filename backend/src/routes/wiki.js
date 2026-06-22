const express = require('express');
const axios = require('axios');

const router = express.Router();

// ─────────────────────────────────────────────────────────────
// Cache immagini + coda a concorrenza limitata (anti-429)
// ─────────────────────────────────────────────────────────────

const imageCache = new Map(); // url -> { contentType, data }

let activeRequests = 0;
const MAX_CONCURRENT = 1;

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function acquireSlot() {
  while (activeRequests >= MAX_CONCURRENT) {
    await wait(150);
  }
  activeRequests++;
}

function releaseSlot() {
  activeRequests = Math.max(0, activeRequests - 1);
}

// Scarica un'immagine; se Wikimedia risponde 429, aspetta e riprova una volta
async function fetchImage(url) {
  const headers = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
      '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept': 'image/avif,image/webp,image/png,image/*,*/*;q=0.8',
    'Referer': 'https://it.wikipedia.org/',
  };

  try {
    return await axios.get(url, { responseType: 'arraybuffer', headers });
  } catch (error) {
    if (error.response?.status === 429) {
      await wait(1500);
      return await axios.get(url, { responseType: 'arraybuffer', headers });
    }
    throw error;
  }
}

// ─────────────────────────────────────────────────────────────
// Client Wikipedia (API JSON)
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// GET /summary
// ─────────────────────────────────────────────────────────────

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
        titolo: query,
        descrizione: 'Descrizione non disponibile da Wikipedia.',
        wikipediaUrl: null,
        immagineUrl: null,
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

// ─────────────────────────────────────────────────────────────
// GET /images
// ─────────────────────────────────────────────────────────────

router.get('/images', async (req, res) => {
  const query = req.query.q;

  if (!query) {
    return res.status(400).json({ message: 'Parametro q mancante' });
  }

  try {
    // 1. Trova il titolo della pagina
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

    // 2. Immagine principale (la più affidabile)
    const mainImageResponse = await wikiClient.get(
      'https://it.wikipedia.org/w/api.php',
      {
        params: {
          action: 'query',
          titles: title,
          prop: 'pageimages',
          piprop: 'original',
          format: 'json',
          origin: '*',
        },
      },
    );

    const mainPages = mainImageResponse.data?.query?.pages || {};
    const mainPage = Object.values(mainPages)[0];
    const mainUrl = mainPage?.original?.source;

    // 3. Galleria della pagina, filtrata (max 4 per non sovraccaricare Wikimedia)
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

    const BLOCKLIST = [
      'logo', 'icon', 'map', 'flag', 'bandiera', 'stemma',
      'coat_of_arms', 'wiki', 'commons', 'edit', 'symbol',
      'disambig', 'question', 'gnome', 'crystal',
    ];

    const usefulImages = images
      .map((img) => img.title)
      .filter((t) => {
        const lower = t.toLowerCase();
        const isPhoto =
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp');
        const isBlocked = BLOCKLIST.some((b) => lower.includes(b));
        return isPhoto && !isBlocked;
      })
      .slice(0, 4);

    let galleryUrls = [];

    if (usefulImages.length > 0) {
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
      galleryUrls = Object.values(imagePages)
        .map((imgPage) => imgPage.imageinfo?.[0]?.url)
        .filter(Boolean);
    }

    // Immagine principale per prima, senza duplicati
    const allUrls = mainUrl
      ? [mainUrl, ...galleryUrls.filter((u) => u !== mainUrl)]
      : galleryUrls;

    return res.json(allUrls);
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

// ─────────────────────────────────────────────────────────────
// GET /image-proxy
//   Scarica le immagini da upload.wikimedia.org evitando il 403
//   (User-Agent browser + Referer) e il 429 (cache + coda + retry).
// ─────────────────────────────────────────────────────────────

router.get('/image-proxy', async (req, res) => {
  const url = req.query.url;

  if (!url || !url.startsWith('https://upload.wikimedia.org/')) {
    return res.status(400).json({ message: 'URL non valido' });
  }

  // Cache hit: nessuna richiesta a Wikimedia
  if (imageCache.has(url)) {
    const cached = imageCache.get(url);
    res.set('Content-Type', cached.contentType);
    res.set('Cache-Control', 'public, max-age=86400');
    return res.send(cached.data);
  }

  await acquireSlot();

  try {
    const imageResponse = await fetchImage(url);
    const contentType = imageResponse.headers['content-type'] || 'image/jpeg';

    // Salva in cache (limite per non riempire la RAM)
    if (imageCache.size < 500) {
      imageCache.set(url, { contentType, data: imageResponse.data });
    }

    // Pausa per non martellare Wikimedia
    await wait(200);

    res.set('Content-Type', contentType);
    res.set('Cache-Control', 'public, max-age=86400');
    return res.send(imageResponse.data);
  } catch (error) {
    console.error('Errore proxy immagine:', error.message, '->', url);
    return res.status(502).json({ message: 'Immagine non disponibile' });
  } finally {
    releaseSlot();
  }
});

module.exports = router;