import 'package:flutter/material.dart';
import 'itinerary_detail_screen.dart' show ItineraryStop;
import '../widgets/easytour_header.dart';
// ─────────────────────────────────────────────────────────────────────────────
//  TRAVEL DIARY SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class TravelDiaryScreen extends StatefulWidget {
  final ItineraryStop stop;

  const TravelDiaryScreen({super.key, required this.stop});

  @override
  State<TravelDiaryScreen> createState() => _TravelDiaryScreenState();
}

class _TravelDiaryScreenState extends State<TravelDiaryScreen> {
  // ── palette ──────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _primaryLight = Color(0xFFE8EFFD);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _background = Color(0xFFF9FAFB);
  static const Color _gold = Color(0xFFF59E0B);
  static const Color _cardBg = Color(0xFFF0F4FF);

  // ── report categories ────────────────────────────────────────────────────
  static const List<String> _reportCategories = [
    'Affollamento',
    'Pulizia',
    'Accessibilità',
    'Manutenzione',
    'Mancanza di servizi',
    'Segnaletica',
    'Altro',
  ];

  // ── diary state ───────────────────────────────────────────────────────────
  int _diaryRating = 4; // 0–5
  final TextEditingController _notesCtrl = TextEditingController(
    text: 'Posto magnifico, soprattutto la sera quando è illuminato. Atmosfera unica!',
  );
  final List<String> _photos = ['placeholder']; // placeholder = 1 foto già caricata

  // ── report state ──────────────────────────────────────────────────────────
  String _selectedCategory = 'Affollamento';
  final TextEditingController _reportCtrl = TextEditingController(
    text: 'Troppa gente, mancano panchine e zone d\'attesa.',
  );
  bool _reportSent = false;
  bool _diarySaved = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    _reportCtrl.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  void _saveDiary() {
    // TODO: persist to backend
    setState(() => _diarySaved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diario salvato'),
        backgroundColor: Color(0xFF1A56DB),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _sendReport() {
    if (_reportCtrl.text.trim().isEmpty) return;
    // TODO: POST to backend
    setState(() => _reportSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Segnalazione inviata al Comune'),
        backgroundColor: Color(0xFF166534),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── itinerary header card ─────────────────────────────────────────
          _buildItineraryHeader(),
          const SizedBox(height: 16),
          // ── private diary ─────────────────────────────────────────────────
          _buildDiaryCard(),
          const SizedBox(height: 16),
          // ── report to municipality ────────────────────────────────────────
          _buildReportCard(),
          const SizedBox(height: 8),
          // ── public disclaimer ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 13, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  'Le segnalazioni sono pubbliche e inviate al tuo Comune.',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── app bar ────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.navigation_outlined,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          const Text(
            'TripBuddy',
            style: TextStyle(
              color: _primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined, color: _textPrimary),
          onPressed: () {},
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _divider, height: 1),
      ),
    );
  }

  // ── itinerary header ───────────────────────────────────────────────────────
  Widget _buildItineraryHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // title section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Diario di viaggio',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Salva i tuoi ricordi e aiuta la tua città',
                style: TextStyle(fontSize: 13, color: _textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // itinerary saved chip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.luggage_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Itinerario salvato',
                        style: TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                        ),
                      ),
                      const Text(
                        'Weekend a Roma',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const Text(
                        '3 giorni  •  8 luoghi',
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _textSecondary, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // selected place chip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC7D7F8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.place_outlined,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Luogo selezionato',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.stop.placeName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        widget.stop.placeAddress,
                        style: const TextStyle(
                            fontSize: 11, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                // thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 56,
                    height: 46,
                    color: const Color(0xFFD1E0FB),
                    child: const Icon(Icons.photo_outlined,
                        color: _primary, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── private diary card ─────────────────────────────────────────────────────
  Widget _buildDiaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Il tuo diario (privato)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 13, color: _textSecondary),
                  const SizedBox(width: 3),
                  const Text(
                    'Visibile solo a te',
                    style: TextStyle(fontSize: 11, color: _textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // rating
          const Text(
            'Valuta la tua esperienza',
            style: TextStyle(fontSize: 13, color: _textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => _diaryRating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    i < _diaryRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: _gold,
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // notes
          const Text(
            'Note personali',
            style: TextStyle(fontSize: 13, color: _textSecondary),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _divider),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _notesCtrl,
              maxLength: 500,
              maxLines: 4,
              style: const TextStyle(fontSize: 14, color: _textPrimary),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: InputBorder.none,
                counterStyle: TextStyle(fontSize: 11, color: _textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // photos
          const Text(
            'Foto ricordo (facoltativo)',
            style: TextStyle(fontSize: 13, color: _textSecondary),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // existing photos
                ..._photos.map((p) => _PhotoThumbnail(
                      hasImage: true,
                      onRemove: () => setState(() => _photos.remove(p)),
                    )),
                // add photo button
                _PhotoAddButton(
                    onTap: () => setState(() => _photos.add('new'))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // save button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _saveDiary,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                _diarySaved ? 'Salvato ✓' : 'Salva diario',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── report card ────────────────────────────────────────────────────────────
  Widget _buildReportCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            children: [
              const Text(
                'Segnalazione al Comune',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'facoltativa',
                  style: TextStyle(
                      fontSize: 10, color: _primary, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Aiutaci a migliorare la città per tutti',
            style: TextStyle(fontSize: 12, color: _textSecondary),
          ),
          const SizedBox(height: 14),
          // category dropdown
          const Text(
            'Categoria',
            style: TextStyle(fontSize: 13, color: _textSecondary),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _divider),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              onChanged: _reportSent
                  ? null
                  : (v) => setState(() => _selectedCategory = v!),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.people_outline,
                    color: Color(0xFF6B7280), size: 20),
              ),
              items: _reportCategories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c,
                            style: const TextStyle(
                                fontSize: 14, color: _textPrimary)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          // description
          const Text(
            'La tua segnalazione',
            style: TextStyle(fontSize: 13, color: _textSecondary),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _divider),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _reportCtrl,
              maxLength: 300,
              maxLines: 3,
              enabled: !_reportSent,
              style: const TextStyle(fontSize: 14, color: _textPrimary),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: InputBorder.none,
                counterStyle: TextStyle(fontSize: 11, color: _textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // send button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _reportSent ? null : _sendReport,
              icon: const Icon(Icons.send_outlined,
                  color: Colors.white, size: 18),
              label: Text(
                _reportSent ? 'Segnalazione inviata ✓' : 'Invia segnalazione',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _reportSent
                    ? const Color(0xFF166534)
                    : _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PHOTO WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoThumbnail extends StatelessWidget {
  final bool hasImage;
  final VoidCallback onRemove;

  const _PhotoThumbnail({required this.hasImage, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 76,
          height: 76,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFD1E0FB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.photo_outlined,
              color: Color(0xFF1A56DB), size: 28),
        ),
        Positioned(
          top: 2,
          right: 10,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 13, color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PhotoAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          border: Border.all(
              color: const Color(0xFFD1D5DB), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.camera_alt_outlined,
                color: Color(0xFF6B7280), size: 22),
            SizedBox(height: 2),
            Text('Aggiungi foto',
                style: TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}