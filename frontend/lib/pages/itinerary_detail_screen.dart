import 'package:flutter/material.dart';
import 'saved_itinerary_screen.dart' show SavedItinerary;
import 'place_detail_screen.dart';
import '../widgets/easytour_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL
// ─────────────────────────────────────────────────────────────────────────────

class ItineraryStop {
  final String id;
  final int order;
  final int day;
  final String placeName;
  final String placeAddress;
  final String placeCategory;
  final String imageUrl;
  final double rating;
  final int reviewsCount;
  final String description;
  final double latitude;
  final double longitude;
  final String estimatedArrival;
  final int estimatedMinutes;

  const ItineraryStop({
    required this.id,
    required this.order,
    required this.day,
    required this.placeName,
    required this.placeAddress,
    required this.placeCategory,
    required this.imageUrl,
    required this.rating,
    required this.reviewsCount,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.estimatedArrival,
    required this.estimatedMinutes,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ItineraryDetailScreen extends StatelessWidget {
  final SavedItinerary itinerary;

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _primaryLight = Color(0xFFE8EFFD);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _background = Color(0xFFF9FAFB);
  static const Color _gold = Color(0xFFF59E0B);

  const ItineraryDetailScreen({super.key, required this.itinerary});

  // ── mock stops (sostituire con fetch dal backend) ─────────────────────────
  List<ItineraryStop> get _stops => [
    const ItineraryStop(
      id: 's1',
      order: 1,
      day: 1,
      placeName: 'Fontana di Trevi',
      placeAddress: 'Piazza di Trevi, Roma',
      placeCategory: 'Monumento',
      imageUrl: '',
      rating: 4.7,
      reviewsCount: 12345,
      description:
          'La più grande e famosa fontana barocca di Roma, progettata da Nicola Salvi e completata nel 1762.',
      latitude: 41.9009,
      longitude: 12.4833,
      estimatedArrival: '09:00',
      estimatedMinutes: 60,
    ),
    const ItineraryStop(
      id: 's2',
      order: 2,
      day: 1,
      placeName: 'Colosseo',
      placeAddress: 'Piazza del Colosseo, Roma',
      placeCategory: 'Sito storico',
      imageUrl: '',
      rating: 4.8,
      reviewsCount: 98210,
      description:
          'L\'anfiteatro più grande mai costruito, simbolo dell\'Impero Romano e dell\'architettura antica.',
      latitude: 41.8902,
      longitude: 12.4922,
      estimatedArrival: '10:30',
      estimatedMinutes: 90,
    ),
    const ItineraryStop(
      id: 's3',
      order: 3,
      day: 1,
      placeName: 'Foro Romano',
      placeAddress: 'Via Sacra, Roma',
      placeCategory: 'Sito storico',
      imageUrl: '',
      rating: 4.6,
      reviewsCount: 44320,
      description:
          'Il cuore dell\'antica Roma, sede delle attività politiche, religiose e commerciali della città.',
      latitude: 41.8925,
      longitude: 12.4853,
      estimatedArrival: '12:15',
      estimatedMinutes: 75,
    ),
    const ItineraryStop(
      id: 's4',
      order: 4,
      day: 2,
      placeName: 'Musei Vaticani',
      placeAddress: 'Viale Vaticano, Città del Vaticano',
      placeCategory: 'Museo',
      imageUrl: '',
      rating: 4.7,
      reviewsCount: 67890,
      description:
          'Uno dei musei più grandi del mondo, con una collezione artistica unica che include la Cappella Sistina.',
      latitude: 41.9065,
      longitude: 12.4536,
      estimatedArrival: '09:30',
      estimatedMinutes: 180,
    ),
  ];

  // ── group by day ──────────────────────────────────────────────────────────
  Map<int, List<ItineraryStop>> get _stopsByDay {
    final map = <int, List<ItineraryStop>>{};
    for (final s in _stops) {
      map.putIfAbsent(s.day, () => []).add(s);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final byDay = _stopsByDay;
    final days = byDay.keys.toList()..sort();

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          itinerary.title,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _divider, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── header card ──────────────────────────────────────────────────
          _buildHeaderCard(),
          const SizedBox(height: 20),
          // ── stops per day ─────────────────────────────────────────────────
          ...days.map((day) => _buildDaySection(context, day, byDay[day]!)),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.luggage_outlined, color: _primary, size: 24),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: _textSecondary, size: 13),
                    const SizedBox(width: 2),
                    Text(
                      itinerary.municipality,
                      style: const TextStyle(fontSize: 13, color: _textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _HeaderChip(
                      icon: Icons.calendar_today_outlined,
                      label: '${itinerary.days} ${itinerary.days == 1 ? "giorno" : "giorni"}',
                    ),
                    const SizedBox(width: 8),
                    _HeaderChip(
                      icon: Icons.place_outlined,
                      label: '${_stops.length} tappe',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(
      BuildContext context, int day, List<ItineraryStop> stops) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Giorno $day',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...stops.asMap().entries.map((e) {
          final isLast = e.key == stops.length - 1;
          return _StopTile(
            stop: e.value,
            isLast: isLast,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlaceDetailScreen(stop: e.value),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STOP TILE
// ─────────────────────────────────────────────────────────────────────────────

class _StopTile extends StatelessWidget {
  final ItineraryStop stop;
  final bool isLast;
  final VoidCallback onTap;

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _primaryLight = Color(0xFFE8EFFD);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _gold = Color(0xFFF59E0B);

  const _StopTile({
    required this.stop,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── timeline column ───────────────────────────────────────────────
          SizedBox(
            width: 56,
            child: Column(
              children: [
                const SizedBox(height: 14),
                // circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: _primary, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${stop.order}',
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                // line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFFD1D5DB),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          // ── card ─────────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 16, bottom: isLast ? 0 : 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stop.placeName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    stop.placeAddress,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: _textSecondary, size: 18),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Rating
                            Icon(Icons.star_rounded, color: _gold, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              stop.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 10),
                            // Category
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                stop.placeCategory,
                                style: const TextStyle(
                                    fontSize: 11, color: _textSecondary),
                              ),
                            ),
                            const Spacer(),
                            // Time
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 12, color: _textSecondary),
                                const SizedBox(width: 3),
                                Text(
                                  stop.estimatedArrival,
                                  style: const TextStyle(
                                      fontSize: 12, color: _textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}