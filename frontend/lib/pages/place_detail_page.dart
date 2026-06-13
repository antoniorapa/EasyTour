import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/place.dart';
import '../services/api_service.dart';
import '../widgets/easytour_header.dart';

class PlaceDetailPage extends StatefulWidget {
  final String placeId;

  const PlaceDetailPage({
    super.key,
    required this.placeId,
  });

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  final ApiService apiService = ApiService();

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBackground = Color(0xFFF7FAFC);
  static const Color softBlue = Color(0xFFEAF4FA);
  static const Color softOrange = Color(0xFFFFF2DF);

  bool isLoading = true;
  String? errorMessage;

  Place? place;
  String? wikipediaDescription;
  String? wikipediaUrl;

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

    try {
      final detailData = await apiService.getGooglePlaceDetailRaw(
        widget.placeId,
      );

      final loadedPlace = Place.fromJson(detailData);

      final reviews = detailData['recensioniGoogle'];

      final List<Map<String, dynamic>> loadedReviews =
      reviews is List ? reviews.cast<Map<String, dynamic>>() : [];

      final List<String> loadedImages = [];

      final photoToken = loadedPlace.photoReference ?? loadedPlace.photoName;

      if (photoToken != null && photoToken.isNotEmpty) {
        try {
          final googlePhotoUrl = await apiService.getGooglePlacePhotoUrl(
            photoToken,
          );

          if (googlePhotoUrl != null && googlePhotoUrl.isNotEmpty) {
            loadedImages.add(googlePhotoUrl);
          }
        } catch (_) {}
      }

      try {
        final wikiSummary = await apiService.getWikipediaSummary(
          loadedPlace.nome,
        );

        wikipediaDescription =
            wikiSummary['descrizione']?.toString() ?? loadedPlace.descrizione;

        wikipediaUrl = wikiSummary['wikipediaUrl']?.toString();

        final wikiImageUrl = wikiSummary['immagineUrl']?.toString();

        if (wikiImageUrl != null && wikiImageUrl.isNotEmpty) {
          loadedImages.add(wikiImageUrl);
        }
      } catch (_) {
        wikipediaDescription = loadedPlace.descrizione;
      }

      try {
        final wikiImages = await apiService.getWikipediaImages(
          loadedPlace.nome,
        );

        for (final imageUrl in wikiImages) {
          if (imageUrl.isNotEmpty) {
            loadedImages.add(imageUrl);
          }
        }
      } catch (_) {}

      final uniqueImages = loadedImages.toSet().toList();

      if (!mounted) return;

      setState(() {
        place = loadedPlace;
        recensioniGoogle = loadedReviews;
        imageUrls = uniqueImages;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Errore nel caricamento del dettaglio: $e';
        isLoading = false;
      });
    }
  }

  Future<void> openGoogleMaps() async {
    final currentPlace = place;

    if (currentPlace == null) return;

    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${currentPlace.latitudine},${currentPlace.longitudine}&query_place_id=${widget.placeId}',
    );

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
    final currentPlace = place;

    if (currentPlace == null) return;

    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${currentPlace.latitudine},${currentPlace.longitudine}&query_place_id=${widget.placeId}',
    );

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
    final currentPlace = place;

    if (currentPlace == null || currentPlace.rating <= 0) {
      return '-';
    }

    return currentPlace.rating.toStringAsFixed(1);
  }

  String _reviewsText() {
    final currentPlace = place;

    if (currentPlace == null || currentPlace.numeroRecensioni <= 0) {
      return 'Recensioni non disponibili';
    }

    return '${currentPlace.numeroRecensioni} recensioni';
  }

  String _addressText() {
    final currentPlace = place;

    if (currentPlace == null) return '';

    if (currentPlace.indirizzo != null &&
        currentPlace.indirizzo!.trim().isNotEmpty) {
      return currentPlace.indirizzo!;
    }

    return 'Indirizzo non disponibile';
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
          if (!isLoading && errorMessage == null && place != null)
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
    final currentPlace = place!;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildImageHeader(),
        _buildMainInfo(currentPlace),
        _buildDescriptionSection(),
        _buildLocationSection(currentPlace),
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
                  imageUrls[index],
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

  Widget _buildMainInfo(Place currentPlace) {
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
            currentPlace.nome,
            style: const TextStyle(
              color: darkBlue,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            currentPlace.categoria,
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

  Widget _buildLocationSection(Place currentPlace) {
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
              'Coordinate: ${currentPlace.latitudine.toStringAsFixed(5)}, ${currentPlace.longitudine.toStringAsFixed(5)}',
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
    );
  }
}