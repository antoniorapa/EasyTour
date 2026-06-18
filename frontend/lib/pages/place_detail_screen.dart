import 'package:flutter/material.dart';
import 'itinerary_detail_screen.dart' show ItineraryStop;
import 'travel_diary_screen.dart';
import '../widgets/easytour_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PLACE DETAIL SCREEN  (versione aggiornata con bottone "Diario di viaggio")
// ─────────────────────────────────────────────────────────────────────────────

class PlaceDetailScreen extends StatelessWidget {
  final ItineraryStop stop;

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _gold = Color(0xFFF59E0B);
  static const Color _background = Color(0xFFF9FAFB);

  const PlaceDetailScreen({super.key, required this.stop});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── hero image + back button ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: _textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            centerTitle: true,
            title: const Text(
              'Dettaglio luogo',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroImage(imageUrl: stop.imageUrl),
            ),
          ),
          // ── content ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // name
                  Text(
                    stop.placeName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // rating row
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        if (i < stop.rating.floor()) {
                          return const Icon(Icons.star_rounded,
                              color: _gold, size: 18);
                        } else if (i < stop.rating && stop.rating % 1 >= 0.5) {
                          return const Icon(Icons.star_half_rounded,
                              color: _gold, size: 18);
                        }
                        return const Icon(Icons.star_outline_rounded,
                            color: _gold, size: 18);
                      }),
                      const SizedBox(width: 6),
                      Text(
                        '${stop.rating} (${_formatCount(stop.reviewsCount)} recensioni)',
                        style: const TextStyle(
                            fontSize: 13, color: _textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // chips row
                  Row(
                    children: [
                      _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: stop.placeAddress.split(',').last.trim()),
                      const SizedBox(width: 8),
                      _InfoChip(
                          icon: Icons.domain_outlined,
                          label: stop.placeAddress.split(',').first.trim(),
                          maxWidth: 120),
                      const SizedBox(width: 8),
                      _InfoChip(
                          icon: Icons.account_balance_outlined,
                          label: stop.placeCategory),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // description header
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: _primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_outline,
                            color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Descrizione',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    stop.description,
                    style: const TextStyle(
                        fontSize: 14,
                        color: _textPrimary,
                        height: 1.55),
                  ),
                  const SizedBox(height: 20),
                  // map tile
                  _MapTile(stop: stop),
                ],
              ),
            ),
          ),
        ],
      ),
      // ── bottom buttons ────────────────────────────────────────────────────
      bottomNavigationBar: _BottomBar(stop: stop),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}.${((n % 1000) ~/ 100)}k';
    return n.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  final String imageUrl;

  const _HeroImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EFFD),
      child: imageUrl.isNotEmpty
          ? Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity)
          : const Center(
              child: Icon(Icons.photo_outlined,
                  color: Color(0xFF1A56DB), size: 48)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final double? maxWidth;

  const _InfoChip({required this.icon, required this.label, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth!) : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  final ItineraryStop stop;

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);

  const _MapTile({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // mini-map placeholder
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13),
              bottomLeft: Radius.circular(13),
            ),
            child: Container(
              width: 90,
              height: 70,
              color: const Color(0xFFDCFCE7),
              child: const Center(
                child: Icon(Icons.map_outlined,
                    color: Color(0xFF166534), size: 30),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.placeAddress,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Nel centro di ${stop.placeAddress.split(',').last.trim()}',
                    style: const TextStyle(
                        fontSize: 11, color: _textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.refresh_outlined, size: 13, color: _primary),
                      const SizedBox(width: 3),
                      Text(
                        'Apri in app Mappe',
                        style: TextStyle(
                          fontSize: 12,
                          color: _primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.chevron_right,
                color: Color(0xFF6B7280), size: 18),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOTTOM BAR  — "Parti" + "Diario di viaggio"  (NUOVA AGGIUNTA)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final ItineraryStop stop;

  static const Color _primary = Color(0xFF1A56DB);

  const _BottomBar({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Parti ─────────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: openMapsNavigation(stop.latitude, stop.longitude)
              },
              icon: const Icon(Icons.navigation_outlined,
                  color: Colors.white, size: 20),
              label: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Parti',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  Text('Apri navigazione verso questo luogo',
                      style: TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Diario di viaggio  (NUOVO) ────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TravelDiaryScreen(stop: stop),
                  ),
                );
              },
              icon: const Icon(Icons.book_outlined, color: _primary, size: 20),
              label: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Diario di viaggio',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _primary)),
                  Text('Salva ricordi di questo luogo',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280))),
                ],
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}