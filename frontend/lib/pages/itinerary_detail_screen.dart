import 'package:flutter/material.dart';
import 'place_detail_screen.dart';
import '../widgets/easytour_header.dart';
import 'saved_itinerary_screen.dart' show SavedItinerary, SavedItineraryStop;
import '../services/api_service.dart';
// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ItineraryDetailScreen extends StatelessWidget {
  final SavedItinerary itinerary;

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBackground = Color(0xFFF7FAFC);
  static const Color softBlue = Color(0xFFEAF4FA);
  static const Color green = Color(0xFF00A676);
  static const Color gold = Color(0xFFF59E0B);

  const ItineraryDetailScreen({
    super.key,
    required this.itinerary,
  });

  Map<int, List<SavedItineraryStop>> get _stopsByDay {
    final map = <int, List<SavedItineraryStop>>{};

    for (final stop in itinerary.stops) {
      map.putIfAbsent(stop.giorno, () => []).add(stop);
    }

    for (final entry in map.entries) {
      entry.value.sort((a, b) => a.ordine.compareTo(b.ordine));
    }

    return map;
  }

  int get _totalMinutes {
    return itinerary.stops.fold<int>(
      0,
          (sum, stop) =>
      sum +
          stop.tempoArrivoStimato +
          stop.tempoVisitaStimato +
          stop.tempoPausaStimato,
    );
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) return '$remainingMinutes min';
    if (remainingMinutes == 0) return '${hours}h';

    return '${hours}h ${remainingMinutes}min';
  }

  String _filterLabel() {
    final filter = itinerary.filter;

    if (filter == null || filter.trim().isEmpty) return 'Tutti';

    return filter;
  }

  String _arrivalClockForDayStop(
      List<SavedItineraryStop> dayStops,
      int localIndex,
      ) {
    int minutes = 0;

    for (int i = 0; i < localIndex; i++) {
      minutes += dayStops[i].tempoArrivoStimato;
      minutes += dayStops[i].tempoVisitaStimato;
      minutes += dayStops[i].tempoPausaStimato;
    }

    minutes += dayStops[localIndex].tempoArrivoStimato;

    const startHour = 9;
    final total = startHour * 60 + minutes;
    final hour = total ~/ 60;
    final minute = total % 60;

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final byDay = _stopsByDay;
    final days = byDay.keys.toList()..sort();

    return Scaffold(
      backgroundColor: lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            const EasyTourHeader(
              showBack: true,
              showLogout: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  _buildIntroBox(),
                  const SizedBox(height: 16),
                  _buildStatsBox(),
                  const SizedBox(height: 22),
                  if (itinerary.stops.isEmpty)
                    _buildEmptyStopsBox()
                  else
                    ...days.map(
                          (day) => _buildDaySection(
                        context: context,
                        day: day,
                        dayStops: byDay[day]!,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFDDEBFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: primaryBlue,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itinerary.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0D1B2A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  itinerary.municipality,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4A5568),
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _statItem(
            icon: Icons.calendar_today_rounded,
            iconColor: primaryBlue,
            title: 'Giorni',
            value: '${itinerary.days}',
          ),
          _verticalDivider(),
          _statItem(
            icon: Icons.place_rounded,
            iconColor: orange,
            title: 'Tappe',
            value: '${itinerary.stops.length}',
          ),
          _verticalDivider(),
          _statItem(
            icon: Icons.schedule_rounded,
            iconColor: green,
            title: 'Durata',
            value: _formatMinutes(_totalMinutes),
          ),
          _verticalDivider(),
          _statItem(
            icon: Icons.filter_alt_rounded,
            iconColor: primaryBlue,
            title: 'Filtro',
            value: _filterLabel(),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF5F6B7A),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 68,
      width: 1,
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildEmptyStopsBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text(
        'Questo itinerario non contiene tappe salvate. Controlla che il backend restituisca la lista stops.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.black54,
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDaySection({
    required BuildContext context,
    required int day,
    required List<SavedItineraryStop> dayStops,
  }) {
    final dayMinutes = dayStops.fold<int>(
      0,
          (sum, stop) =>
      sum +
          stop.tempoArrivoStimato +
          stop.tempoVisitaStimato +
          stop.tempoPausaStimato,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDayHeader(day, dayMinutes),
          const SizedBox(height: 12),
          Column(
            children: List.generate(dayStops.length, (index) {
              final stop = dayStops[index];

              return _buildTimelineRow(
                context: context,
                stop: stop,
                arrivalLabel: _arrivalClockForDayStop(dayStops, index),
                isLast: index == dayStops.length - 1,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(int day, int dayMinutes) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: primaryBlue.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: const BoxDecoration(
              color: primaryBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$day',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Giorno $day',
              style: const TextStyle(
                color: darkBlue,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            _formatMinutes(dayMinutes),
            style: const TextStyle(
              color: primaryBlue,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow({
    required BuildContext context,
    required SavedItineraryStop stop,
    required String arrivalLabel,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Text(
                  arrivalLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 27,
                  width: 27,
                  decoration: const BoxDecoration(
                    color: primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      stop.ordine.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StopCard(
                stop: stop,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlaceDetailScreen(stop: stop),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CARD TAPPA
// ─────────────────────────────────────────────────────────────────────────────

class _StopCard extends StatelessWidget {
  final SavedItineraryStop stop;
  final VoidCallback onTap;

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color orange = Color(0xFFF58A00);
  static const Color green = Color(0xFF00A676);
  static const Color gold = Color(0xFFF59E0B);

  const _StopCard({
    required this.stop,
    required this.onTap,
  });

  String _formatMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              _StopImage(stop: stop),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.placeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 14,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stop.placeCategory.isEmpty
                          ? 'Categoria non disponibile'
                          : stop.placeCategory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _SmallChip(
                            icon: Icons.directions_walk_rounded,
                            text: _formatMinutes(stop.tempoArrivoStimato),
                            color: green,
                          ),
                          const SizedBox(width: 5),
                          _SmallChip(
                            icon: Icons.schedule_rounded,
                            text: _formatMinutes(stop.tempoVisitaStimato),
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 5),
                          _SmallChip(
                            icon: Icons.coffee_rounded,
                            text: _formatMinutes(stop.tempoPausaStimato),
                            color: orange,
                          ),
                          if (stop.rating > 0) ...[
                            const SizedBox(width: 5),
                            _SmallChip(
                              icon: Icons.star_rounded,
                              text: stop.rating.toStringAsFixed(1),
                              color: gold,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: primaryBlue,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopImage extends StatefulWidget {
  final SavedItineraryStop stop;

  const _StopImage({
    required this.stop,
  });

  @override
  State<_StopImage> createState() => _StopImageState();
}

class _StopImageState extends State<_StopImage> {
  final ApiService _apiService = ApiService();

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color orange = Color(0xFFF58A00);

  late Future<String?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _loadImage();
  }

  Future<String?> _loadImage() async {
    final savedImage = widget.stop.imageUrl.trim();

    if (savedImage.isNotEmpty) {
      return savedImage;
    }

    try {
      final wikiSummary = await _apiService.getWikipediaSummary(
        widget.stop.placeName,
      );

      final summaryImage = wikiSummary['immagineUrl'] ??
          wikiSummary['imageUrl'] ??
          wikiSummary['thumbnail']?['source'] ??
          wikiSummary['originalimage']?['source'];

      if (summaryImage != null && summaryImage.toString().trim().isNotEmpty) {
        return summaryImage.toString().trim();
      }
    } catch (_) {}

    try {
      final wikiImages = await _apiService.getWikipediaImages(
        widget.stop.placeName,
      );

      if (wikiImages.isNotEmpty && wikiImages.first.trim().isNotEmpty) {
        return wikiImages.first.trim();
      }
    } catch (_) {}

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _placeholderImage(
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          );
        }

        final imageUrl = snapshot.data;

        if (imageUrl == null || imageUrl.trim().isEmpty) {
          return _placeholderImage(
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 28,
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.network(
            ApiService.resolveImageUrl(imageUrl),
            width: 76,
            height: 76,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return _placeholderImage(
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _placeholderImage({required Widget child}) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [orange, primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(child: child),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SmallChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DETTAGLIO TAPPA
// ─────────────────────────────────────────────────────────────────────────────

class SavedStopDetailPage extends StatelessWidget {
  final SavedItineraryStop stop;

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBackground = Color(0xFFF7FAFC);
  static const Color softBlue = Color(0xFFEAF4FA);
  static const Color green = Color(0xFF00A676);
  static const Color gold = Color(0xFFF59E0B);

  const SavedStopDetailPage({
    super.key,
    required this.stop,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            const EasyTourHeader(
              showBack: true,
              showLogout: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  _buildImage(),
                  const SizedBox(height: 14),
                  _buildMainInfo(),
                  const SizedBox(height: 14),
                  _buildDescription(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (stop.imageUrl.trim().isEmpty) {
      return _placeholderLargeImage();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.network(
        ApiService.resolveImageUrl(stop.imageUrl),
        height: 190,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderLargeImage(),
      ),
    );
  }

  Widget _placeholderLargeImage() {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [orange, primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: Icon(
          Icons.location_on_rounded,
          color: Colors.white,
          size: 70,
        ),
      ),
    );
  }

  Widget _buildMainInfo() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stop.placeName,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: primaryBlue,
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  stop.placeAddress.isEmpty
                      ? 'Indirizzo non disponibile'
                      : stop.placeAddress,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _detailChip(
                  icon: Icons.category_rounded,
                  title: 'Categoria',
                  value: stop.placeCategory.isEmpty
                      ? 'N/D'
                      : stop.placeCategory,
                  color: primaryBlue,
                ),
                const SizedBox(width: 7),
                _detailChip(
                  icon: Icons.schedule_rounded,
                  title: 'Durata',
                  value: '${stop.tempoVisitaStimato} min',
                  color: green,
                ),
                const SizedBox(width: 7),
                _detailChip(
                  icon: Icons.coffee_rounded,
                  title: 'Pausa',
                  value: '${stop.tempoPausaStimato} min',
                  color: orange,
                ),
                if (stop.rating > 0) ...[
                  const SizedBox(width: 7),
                  _detailChip(
                    icon: Icons.star_rounded,
                    title: 'Rating',
                    value: stop.rating.toStringAsFixed(1),
                    color: gold,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailChip({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: softBlue,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: const BoxDecoration(
              color: primaryBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              stop.description.isEmpty
                  ? 'Descrizione non disponibile.'
                  : stop.description,
              style: const TextStyle(
                color: Color(0xFF243B53),
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}