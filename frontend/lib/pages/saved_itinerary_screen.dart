import 'package:flutter/material.dart';
import 'itinerary_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL (minimal – allinea con quanto già presente nel progetto)
// ─────────────────────────────────────────────────────────────────────────────

class SavedItinerary {
  final String id;
  final String title;
  final String municipality;
  final int days;
  final int stopsCount;
  final DateTime createdAt;
  final String? filter; // 'Ho solo 2 ore' | 'Budget limitato' | 'Posti nascosti' | null

  const SavedItinerary({
    required this.id,
    required this.title,
    required this.municipality,
    required this.days,
    required this.stopsCount,
    required this.createdAt,
    this.filter,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SavedItinerariesScreen extends StatefulWidget {
  const SavedItinerariesScreen({super.key});

  @override
  State<SavedItinerariesScreen> createState() => _SavedItinerariesScreenState();
}

class _SavedItinerariesScreenState extends State<SavedItinerariesScreen> {
  // ── palette ──────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _primaryLight = Color(0xFFE8EFFD);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _background = Color(0xFFF9FAFB);

  // ── mock data (sostituire con chiamata al backend) ────────────────────────
  final List<SavedItinerary> _itineraries = [
    SavedItinerary(
      id: '1',
      title: 'Weekend a Roma',
      municipality: 'Roma',
      days: 3,
      stopsCount: 8,
      createdAt: DateTime(2026, 6, 10),
    ),
    SavedItinerary(
      id: '2',
      title: 'Napoli in un giorno',
      municipality: 'Napoli',
      days: 1,
      stopsCount: 5,
      createdAt: DateTime(2026, 5, 28),
      filter: 'Ho solo 2 ore',
    ),
    SavedItinerary(
      id: '3',
      title: 'Posti nascosti di Firenze',
      municipality: 'Firenze',
      days: 2,
      stopsCount: 6,
      createdAt: DateTime(2026, 4, 15),
      filter: 'Posti nascosti',
    ),
  ];

  // ── helpers ───────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) {
    const months = [
      '', 'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
      'lug', 'ago', 'set', 'ott', 'nov', 'dic'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  Color _filterColor(String? filter) {
    if (filter == null) return Colors.transparent;
    switch (filter) {
      case 'Ho solo 2 ore':
        return const Color(0xFFFEF3C7);
      case 'Budget limitato':
        return const Color(0xFFDCFCE7);
      case 'Posti nascosti':
        return const Color(0xFFEDE9FE);
      default:
        return _primaryLight;
    }
  }

  Color _filterTextColor(String? filter) {
    if (filter == null) return Colors.transparent;
    switch (filter) {
      case 'Ho solo 2 ore':
        return const Color(0xFF92400E);
      case 'Budget limitato':
        return const Color(0xFF166534);
      case 'Posti nascosti':
        return const Color(0xFF5B21B6);
      default:
        return _primary;
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'I miei itinerari',
          style: TextStyle(
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
      body: _itineraries.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map_outlined, color: _primary, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nessun itinerario salvato',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inizia a esplorare e salva il tuo primo percorso.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: _itineraries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ItineraryCard(
        itinerary: _itineraries[index],
        filterBg: _filterColor(_itineraries[index].filter),
        filterFg: _filterTextColor(_itineraries[index].filter),
        formattedDate: _formatDate(_itineraries[index].createdAt),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ItineraryDetailScreen(
                itinerary: _itineraries[index],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ItineraryCard extends StatelessWidget {
  final SavedItinerary itinerary;
  final Color filterBg;
  final Color filterFg;
  final String formattedDate;
  final VoidCallback onTap;

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _primaryLight = Color(0xFFE8EFFD);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);

  const _ItineraryCard({
    required this.itinerary,
    required this.filterBg,
    required this.filterFg,
    required this.formattedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.luggage_outlined, color: _primary, size: 24),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + chevron
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            itinerary.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: _textSecondary, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Municipality
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
                    const SizedBox(height: 10),
                    // Meta chips row
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: Icons.calendar_today_outlined,
                          label: '${itinerary.days} ${itinerary.days == 1 ? "giorno" : "giorni"}',
                        ),
                        _MetaChip(
                          icon: Icons.place_outlined,
                          label: '${itinerary.stopsCount} luoghi',
                        ),
                        if (itinerary.filter != null)
                          _FilterChip(
                            label: itinerary.filter!,
                            bg: filterBg,
                            fg: filterFg,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Salvato il $formattedDate',
                      style: const TextStyle(fontSize: 11, color: _textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

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
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _FilterChip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: fg),
      ),
    );
  }
}