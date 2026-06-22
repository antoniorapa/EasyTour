import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'travel_diary_screen.dart';
import '../services/api_service.dart';
import '../widgets/easytour_header.dart';
import 'saved_itinerary_screen.dart' show SavedItineraryStop;

class PlaceDetailScreen extends StatefulWidget {
  final SavedItineraryStop stop;

  const PlaceDetailScreen({
    super.key,
    required this.stop,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  final ApiService apiService = ApiService();

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBackground = Color(0xFFF7FAFC);
  static const Color softBlue = Color(0xFFEAF4FA);
  static const Color softOrange = Color(0xFFFFF2DF);

  bool isLoading = true;
  String? errorMessage;

  String nome = '';
  String categoria = '';
  String indirizzo = '';
  String descrizione = '';
  String? wikipediaDescription;
  String? wikipediaUrl;

  double latitudine = 0;
  double longitudine = 0;
  double rating = 0;
  int numeroRecensioni = 0;

  List<String> imageUrls = [];
  List<Map<String, dynamic>> recensioniGoogle = [];

  int currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    loadPlaceDetail();
  }

  Future<void> loadPlaceDetail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    nome = widget.stop.placeName;
    categoria = widget.stop.placeCategory;
    indirizzo = widget.stop.placeAddress;
    descrizione = widget.stop.description;
    latitudine = widget.stop.latitude;
    longitudine = widget.stop.longitude;
    rating = widget.stop.rating;
    numeroRecensioni = widget.stop.reviewsCount;

    final List<String> loadedImages = [];
    final List<Map<String, dynamic>> loadedReviews = [];

    if (widget.stop.imageUrl.trim().isNotEmpty) {
      loadedImages.add(widget.stop.imageUrl.trim());
    }

    try {
      if (widget.stop.placeId.trim().isNotEmpty) {
        final detailData = await apiService.getGooglePlaceDetailRaw(
          widget.stop.placeId,
        );

        nome = _asString(
          detailData['nome'] ??
              detailData['name'] ??
              detailData['displayName']?['text'],
          fallback: nome,
        );

        categoria = _asString(
          detailData['categoria'] ??
              detailData['category'] ??
              detailData['primaryTypeDisplayName']?['text'],
          fallback: categoria,
        );

        indirizzo = _asString(
          detailData['indirizzo'] ??
              detailData['formattedAddress'] ??
              detailData['address'],
          fallback: indirizzo,
        );

        descrizione = _asString(
          detailData['descrizione'] ?? detailData['description'],
          fallback: descrizione,
        );

        latitudine = _asDouble(
          detailData['latitudine'] ??
              detailData['latitude'] ??
              detailData['lat'] ??
              detailData['location']?['latitude'] ??
              detailData['geometry']?['location']?['lat'],
          fallback: latitudine,
        );

        longitudine = _asDouble(
          detailData['longitudine'] ??
              detailData['longitude'] ??
              detailData['lng'] ??
              detailData['location']?['longitude'] ??
              detailData['geometry']?['location']?['lng'],
          fallback: longitudine,
        );

        rating = _asDouble(
          detailData['rating'] ?? detailData['valutazione'],
          fallback: rating,
        );

        numeroRecensioni = _asInt(
          detailData['numeroRecensioni'] ??
              detailData['userRatingCount'] ??
              detailData['reviewsCount'],
          fallback: numeroRecensioni,
        );

        final reviews = detailData['recensioniGoogle'] ?? detailData['reviews'];

        if (reviews is List) {
          for (final review in reviews) {
            if (review is Map<String, dynamic>) {
              loadedReviews.add(review);
            }
          }
        }

        final photoToken = _asString(
          detailData['photoReference'] ??
              detailData['photoName'] ??
              detailData['photo_reference'] ??
              detailData['photos']?[0]?['name'] ??
              detailData['photos']?[0]?['photo_reference'],
          fallback: '',
        );

        if (photoToken.isNotEmpty) {
          try {
            final googlePhotoUrl = await apiService.getGooglePlacePhotoUrl(
              photoToken,
            );

            if (googlePhotoUrl != null && googlePhotoUrl.isNotEmpty) {
              loadedImages.add(googlePhotoUrl);
            }
          } catch (_) {}
        }
      }

      try {
        final wikiSummary = await apiService.getWikipediaSummary(nome);

        wikipediaDescription =
            wikiSummary['descrizione']?.toString() ??
                wikiSummary['description']?.toString() ??
                wikiSummary['extract']?.toString() ??
                descrizione;

        wikipediaUrl =
            wikiSummary['wikipediaUrl']?.toString() ??
                wikiSummary['content_urls']?['desktop']?['page']?.toString();

        final wikiImageUrl =
            wikiSummary['immagineUrl']?.toString() ??
                wikiSummary['imageUrl']?.toString() ??
                wikiSummary['thumbnail']?['source']?.toString() ??
                wikiSummary['originalimage']?['source']?.toString();

        if (wikiImageUrl != null && wikiImageUrl.isNotEmpty) {
          loadedImages.add(wikiImageUrl);
        }
      } catch (_) {
        wikipediaDescription = descrizione;
      }

      try {
        final wikiImages = await apiService.getWikipediaImages(nome);

        for (final imageUrl in wikiImages) {
          if (imageUrl.isNotEmpty) {
            loadedImages.add(imageUrl);
          }
        }
      } catch (_) {}

      final uniqueImages = loadedImages.toSet().toList();

      if (!mounted) return;

      setState(() {
        recensioniGoogle = loadedReviews;
        imageUrls = uniqueImages;
        isLoading = false;
      });
    } catch (e) {
      try {
        final wikiSummary = await apiService.getWikipediaSummary(nome);

        wikipediaDescription =
            wikiSummary['descrizione']?.toString() ??
                wikiSummary['description']?.toString() ??
                wikiSummary['extract']?.toString() ??
                descrizione;

        wikipediaUrl =
            wikiSummary['wikipediaUrl']?.toString() ??
                wikiSummary['content_urls']?['desktop']?['page']?.toString();

        final wikiImageUrl =
            wikiSummary['immagineUrl']?.toString() ??
                wikiSummary['imageUrl']?.toString() ??
                wikiSummary['thumbnail']?['source']?.toString();

        if (wikiImageUrl != null && wikiImageUrl.isNotEmpty) {
          loadedImages.add(wikiImageUrl);
        }

        final wikiImages = await apiService.getWikipediaImages(nome);

        for (final imageUrl in wikiImages) {
          if (imageUrl.isNotEmpty) {
            loadedImages.add(imageUrl);
          }
        }

        if (!mounted) return;

        setState(() {
          imageUrls = loadedImages.toSet().toList();
          isLoading = false;
        });
      } catch (_) {
        if (!mounted) return;

        setState(() {
          imageUrls = loadedImages.toSet().toList();
          wikipediaDescription = descrizione;
          isLoading = false;
        });
      }
    }
  }

  String _asString(dynamic value, {required String fallback}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty) return fallback;

    return text;
  }

  int _asInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();

    return int.tryParse(value.toString()) ?? fallback;
  }

  double _asDouble(dynamic value, {required double fallback}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();

    return double.tryParse(value.toString()) ?? fallback;
  }

  Future<void> openGoogleMaps() async {
    Uri url;

    if (latitudine != 0 && longitudine != 0) {
      url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitudine,$longitudine&travelmode=walking',
      );
    } else {
      final query = Uri.encodeComponent('$nome $indirizzo');

      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
    }

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire Google Maps.'),
        ),
      );
    }
  }

  Future<void> openGoogleReviews() async {
    Uri url;

    if (widget.stop.placeId.trim().isNotEmpty &&
        latitudine != 0 &&
        longitudine != 0) {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitudine,$longitudine&query_place_id=${widget.stop.placeId}',
      );
    } else if (latitudine != 0 && longitudine != 0) {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitudine,$longitudine',
      );
    } else {
      final query = Uri.encodeComponent('$nome $indirizzo');

      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
    }

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire le recensioni Google.'),
        ),
      );
    }
  }

  Future<void> openWikipedia() async {
    final url = wikipediaUrl;

    if (url == null || url.isEmpty) return;

    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire Wikipedia.'),
        ),
      );
    }
  }

  String _ratingText() {
    if (rating <= 0) {
      return '-';
    }

    return rating.toStringAsFixed(1);
  }

  String _reviewsText() {
    if (numeroRecensioni <= 0) {
      return 'Recensioni non disponibili';
    }

    return '$numeroRecensioni recensioni';
  }

  String _addressText() {
    if (indirizzo.trim().isNotEmpty) {
      return indirizzo;
    }

    return 'Indirizzo non disponibile';
  }

  String _categoryText() {
    if (categoria.trim().isNotEmpty) {
      return categoria;
    }

    return 'Categoria non disponibile';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: Stack(
        children: [
          Column(
            children: [
              EasyTourHeader(
                rightIcon: Icons.arrow_back_rounded,
                onRightIconTap: () => Navigator.pop(context),
              ),
              Expanded(
                child: isLoading
                    ? const Center(
                  child: CircularProgressIndicator(color: primaryBlue),
                )
                    : errorMessage != null
                    ? _buildErrorState()
                    : _buildContent(),
              ),
            ],
          ),
          if (!isLoading && errorMessage == null)
            _buildBottomStartButton(),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: orange,
                size: 48,
              ),
              const SizedBox(height: 14),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: loadPlaceDetail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildImageHeader(),
        _buildMainInfo(),
        _buildDescriptionSection(),
        _buildLocationSection(),
        const SizedBox(height: 105),
      ],
    );
  }

  Widget _buildImageHeader() {
    return Container(
      height: 280,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (imageUrls.isEmpty)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [orange, primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.photo_camera_back_rounded,
                  color: Colors.white,
                  size: 70,
                ),
              ),
            )
          else
            PageView.builder(
              itemCount: imageUrls.length,
              onPageChanged: (index) {
                setState(() {
                  currentImageIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Image.network(
                  ApiService.resolveImageUrl(imageUrls[index]),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [orange, primaryBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white,
                          size: 58,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          Positioned(
            left: 14,
            top: 14,
            child: _glassBadge(
              icon: Icons.image_rounded,
              text: imageUrls.isEmpty
                  ? 'Immagine non disponibile'
                  : '${currentImageIndex + 1}/${imageUrls.length}',
            ),
          ),
          if (imageUrls.length > 1)
            Positioned(
              right: 14,
              bottom: 14,
              child: _glassBadge(
                icon: Icons.swipe_rounded,
                text: 'Scorri',
              ),
            ),
        ],
      ),
    );
  }

  Widget _glassBadge({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainInfo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nome,
            style: const TextStyle(
              color: darkBlue,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _categoryText(),
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _ratingBadgeButton(),
        ],
      ),
    );
  }

  Widget _ratingBadgeButton() {
    return InkWell(
      onTap: openGoogleReviews,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: orange.withOpacity(0.11),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: orange.withOpacity(0.22),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.star_rounded,
              color: orange,
              size: 30,
            ),
            const SizedBox(width: 10),
            Text(
              _ratingText(),
              style: const TextStyle(
                color: orange,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _reviewsText(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.open_in_new_rounded,
              color: orange,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final text =
    wikipediaDescription == null || wikipediaDescription!.trim().isEmpty
        ? 'Descrizione non disponibile per questa attrazione.'
        : wikipediaDescription!;

    return _sectionCard(
      title: 'Descrizione',
      icon: Icons.article_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (wikipediaUrl != null && wikipediaUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: openWikipedia,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    'Continua a leggere su Wiki',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _sectionCard(
      title: 'Posizione',
      icon: Icons.location_on_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _addressText(),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: softBlue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Coordinate: ${latitudine.toStringAsFixed(5)}, ${longitudine.toStringAsFixed(5)}',
              style: const TextStyle(
                color: darkBlue,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 13,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: softOrange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: orange, size: 21),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: darkBlue,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildBottomStartButton() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 18,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TravelDiaryScreen(
                          stop: widget.stop,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryBlue,
                    side: const BorderSide(
                      color: primaryBlue,
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  icon: const Icon(
                    Icons.book_outlined,
                    color: primaryBlue,
                  ),
                  label: const Text(
                    'Vai al diario',
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: openGoogleMaps,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Parti',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}