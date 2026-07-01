import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/easytour_header.dart';
import 'saved_itinerary_screen.dart' show SavedItineraryStop;

// ─────────────────────────────────────────────────────────────────────────────
//  TRAVEL DIARY SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class TravelDiaryScreen extends StatefulWidget {
  final SavedItineraryStop stop;

  const TravelDiaryScreen({
    super.key,
    required this.stop,
  });

  @override
  State<TravelDiaryScreen> createState() => _TravelDiaryScreenState();
}

class _TravelDiaryScreenState extends State<TravelDiaryScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBackground = Color(0xFFF7FAFC);
  static const Color softBlue = Color(0xFFEAF4FA);
  static const Color green = Color(0xFF00A676);
  static const Color dangerRed = Color(0xFFE53935);
  static const Color gold = Color(0xFFF59E0B);

  static const List<String> _reportCategories = [
    'Affollamento',
    'Pulizia',
    'Accessibilità',
    'Manutenzione',
    'Mancanza di servizi',
    'Segnaletica',
    'Altro',
  ];

  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _reportCtrl = TextEditingController();

  // Lista di foto: ogni elemento ha 'id' (nodo Photo) e 'url' (Firebase)
  final List<Map<String, String>> _photos = [];

  int _diaryRating = 0;
  String _selectedCategory = 'Affollamento';

  bool _isLoading = true;
  bool _isSavingDiary = false;
  bool _isSendingReport = false;
  bool _isDeletingReport = false;
  bool _isUploadingPhoto = false;

  bool _diarySaved = false;
  bool _reportSent = false;

  String? _errorMessage;
  String? _reportId;

  @override
  void initState() {
    super.initState();
    _loadDiaryData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _reportCtrl.dispose();
    super.dispose();
  }

  String get _userId {
    return SessionService.currentUserId ?? '';
  }

  String get _address {
    if (widget.stop.placeAddress.trim().isEmpty) {
      return 'Indirizzo non disponibile';
    }

    return widget.stop.placeAddress.trim();
  }

  String get _category {
    if (widget.stop.placeCategory.trim().isEmpty) {
      return 'Categoria non disponibile';
    }

    return widget.stop.placeCategory.trim();
  }

  bool get _canUseDb {
    return _userId.trim().isNotEmpty && widget.stop.id.trim().isNotEmpty;
  }

  Future<void> _loadDiaryData() async {
    if (!_canUseDb) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Impossibile caricare il diario: utente o tappa non disponibili.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.getTravelDiaryForStop(
        userId: _userId,
        stopId: widget.stop.id,
      );

      final diary = data['diary'];
      final report = data['report'];

      if (!mounted) return;

      setState(() {
        if (diary is Map<String, dynamic>) {
          _diaryRating = _asInt(diary['rating'], fallback: 0);
          _notesCtrl.text = _asString(diary['note']);
          _diarySaved =
              _diaryRating > 0 || _notesCtrl.text.trim().isNotEmpty;

          _photos.clear();
        }

        if (report is Map<String, dynamic>) {
          _reportId = _asString(report['id']);
          _selectedCategory =
              _normalizeCategory(_asString(report['categoria']));
          _reportCtrl.text = _asString(report['descrizione']);
          _reportSent = _reportId != null &&
              _reportId!.trim().isNotEmpty &&
              _reportCtrl.text.trim().isNotEmpty;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Errore durante il caricamento del diario: $e';
      });
    }

    // Carica le foto dai nodi Photo collegati alla tappa
    try {
      final photos = await _apiService.getDiaryPhotos(
        userId: _userId,
        stopId: widget.stop.id,
      );
      if (mounted) {
        setState(() {
          _photos
            ..clear()
            ..addAll(photos);
        });
      }
    } catch (_) {
      // se il caricamento foto fallisce, non blocchiamo il diario
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );

      if (picked == null) return; // utente ha annullato

      if (!_canUseDb) {
        _showSnack(message: 'Utente o tappa non disponibili.', color: dangerRed);
        return;
      }

      setState(() {
        _isUploadingPhoto = true;
      });

      // Il DiaryEntry deve esistere PRIMA di collegare la foto.
      // Salviamo (o aggiorniamo) il diario in modo idempotente.
      await _apiService.saveTravelDiaryForStop(
        userId: _userId,
        stopId: widget.stop.id,
        placeId: widget.stop.placeId,
        placeName: widget.stop.placeName,
        rating: _diaryRating,
        note: _notesCtrl.text.trim(),
      );

      // Ora carica la foto: finisce su Firebase e diventa un nodo (:Photo)
      await _apiService.uploadDiaryPhoto(
        File(picked.path),
        userId: _userId,
        stopId: widget.stop.id,
      );

      // Ricarica la lista foto (con id) dai nodi Photo
      final photos = await _apiService.getDiaryPhotos(
        userId: _userId,
        stopId: widget.stop.id,
      );

      if (!mounted) return;

      setState(() {
        _photos
          ..clear()
          ..addAll(photos);
        _isUploadingPhoto = false;
      });

      _showSnack(
        message: 'Foto caricata e collegata alla tappa.',
        color: primaryBlue,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUploadingPhoto = false;
      });

      _showSnack(
        message: 'Errore durante il caricamento della foto: $e',
        color: dangerRed,
      );
    }
  }

  Future<void> _deletePhoto(Map<String, String> photo) async {
    final photoId = photo['id'] ?? '';
    if (photoId.isEmpty) {
      _showSnack(
        message: 'Foto senza id: impossibile eliminarla.',
        color: dangerRed,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminare la foto?'),
          content: const Text(
            'La foto verrà rimossa definitivamente dalla tappa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina', style: TextStyle(color: dangerRed)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _apiService.deleteDiaryPhoto(
        userId: _userId,
        photoId: photoId,
      );

      if (!mounted) return;

      setState(() {
        _photos.removeWhere((p) => p['id'] == photoId);
      });

      _showSnack(message: 'Foto eliminata.', color: green);
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        message: 'Errore durante l\'eliminazione: $e',
        color: dangerRed,
      );
    }
  }

  Future<void> _saveDiary() async {
    if (!_canUseDb) {
      _showSnack(
        message: 'Utente o tappa non disponibili.',
        color: dangerRed,
      );
      return;
    }

    setState(() {
      _isSavingDiary = true;
    });

    try {
      await _apiService.saveTravelDiaryForStop(
        userId: _userId,
        stopId: widget.stop.id,
        placeId: widget.stop.placeId,
        placeName: widget.stop.placeName,
        rating: _diaryRating,
        note: _notesCtrl.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _diarySaved = true;
        _isSavingDiary = false;
      });

      _showSnack(
        message: 'Diario salvato correttamente.',
        color: primaryBlue,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSavingDiary = false;
      });

      _showSnack(
        message: 'Errore durante il salvataggio del diario: $e',
        color: dangerRed,
      );
    }
  }

  Future<void> _sendReport() async {
    if (!_canUseDb) {
      _showSnack(
        message: 'Utente o tappa non disponibili.',
        color: dangerRed,
      );
      return;
    }

    if (_reportCtrl.text.trim().isEmpty) {
      _showSnack(
        message: 'Inserisci una descrizione per la segnalazione.',
        color: dangerRed,
      );
      return;
    }

    setState(() {
      _isSendingReport = true;
    });

    try {
      final result = await _apiService.createTravelReport(
        userId: _userId,
        stopId: widget.stop.id,
        placeId: widget.stop.placeId,
        placeName: widget.stop.placeName,
        categoria: _selectedCategory,
        descrizione: _reportCtrl.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _reportId = _asString(result['reportId'] ?? result['id']);
        _reportSent = true;
        _isSendingReport = false;
      });

      _showSnack(
        message: 'Segnalazione inviata al Comune.',
        color: green,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSendingReport = false;
      });

      _showSnack(
        message: 'Errore durante l’invio della segnalazione: $e',
        color: dangerRed,
      );
    }
  }

  Future<void> _deleteReport() async {
    final reportId = _reportId;

    if (reportId == null || reportId.trim().isEmpty) {
      _showSnack(
        message: 'Segnalazione non trovata.',
        color: dangerRed,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminare la segnalazione?'),
          content: const Text(
            'La segnalazione verrà rimossa dal database e non sarà più visibile al Comune.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Elimina',
                style: TextStyle(color: dangerRed),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isDeletingReport = true;
    });

    try {
      await _apiService.deleteTravelReport(
        userId: _userId,
        reportId: reportId,
      );

      if (!mounted) return;

      setState(() {
        _reportId = null;
        _reportSent = false;
        _reportCtrl.clear();
        _selectedCategory = 'Affollamento';
        _isDeletingReport = false;
      });

      _showSnack(
        message: 'Segnalazione eliminata.',
        color: green,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeletingReport = false;
      });

      _showSnack(
        message: 'Errore durante l’eliminazione: $e',
        color: dangerRed,
      );
    }
  }

  void _showSnack({
    required String message,
    required Color color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openPhotoViewer(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 200,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 34,
                    width: 34,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _asInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();

    return int.tryParse(value.toString()) ?? fallback;
  }

  String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  String _normalizeCategory(String value) {
    if (_reportCategories.contains(value)) return value;
    return 'Altro';
  }

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
              child: RefreshIndicator(
                color: primaryBlue,
                onRefresh: _loadDiaryData,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 90, 16, 24),
        children: const [
          Center(
            child: CircularProgressIndicator(color: primaryBlue),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildIntroBox(),
          const SizedBox(height: 16),
          _buildErrorBox(),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        _buildIntroBox(),
        const SizedBox(height: 16),
        _buildSelectedPlaceBox(),
        const SizedBox(height: 16),
        _buildDiaryCard(),
        const SizedBox(height: 16),
        _buildReportCard(),
        const SizedBox(height: 10),
        _buildDisclaimer(),
      ],
    );
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: dangerRed,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDiaryData,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Riprova'),
          ),
        ],
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
              Icons.book_rounded,
              color: primaryBlue,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diario di viaggio',
                  style: TextStyle(
                    color: Color(0xFF0D1B2A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Salva ricordi personali e, se vuoi, invia una segnalazione utile al Comune.',
                  style: TextStyle(
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

  Widget _buildSelectedPlaceBox() {
    return Container(
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
          _buildPlaceImage(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.stop.placeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: primaryBlue,
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        _address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildPlaceImage() {
    if (widget.stop.imageUrl.trim().isEmpty) {
      return _placeholderImage();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Image.network(
        ApiService.resolveImageUrl(widget.stop.imageUrl),
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      ),
    );
  }

  Widget _placeholderImage() {
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
      child: const Center(
        child: Icon(
          Icons.location_on_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildDiaryCard() {
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
          _sectionHeader(
            icon: Icons.lock_outline_rounded,
            title: 'Il tuo diario privato',
            subtitle: 'Visibile solo a te',
            color: primaryBlue,
          ),
          const SizedBox(height: 16),
          const Text(
            'Valuta la tua esperienza',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final selected = index < _diaryRating;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _diaryRating = index + 1;
                    _diarySaved = false;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Icon(
                    selected
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: gold,
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          const Text(
            'Note personali',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _notesCtrl,
            maxLength: 500,
            maxLines: 4,
            onChanged: (_) {
              if (_diarySaved) {
                setState(() {
                  _diarySaved = false;
                });
              }
            },
            decoration: _inputDecoration(
              hint:
                  'Scrivi un ricordo, una sensazione o qualcosa che vuoi ricordare...',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Foto ricordo',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._photos.map(
                  (photo) => _PhotoThumbnail(
                    imageUrl: ApiService.resolveImageUrl(photo['url']!),
                    onTap: () =>
                        _openPhotoViewer(ApiService.resolveImageUrl(photo['url']!)),
                    onRemove: () => _deletePhoto(photo),
                  ),
                ),
                _PhotoAddButton(
                  isLoading: _isUploadingPhoto,
                  onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSavingDiary ? null : _saveDiary,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primaryBlue.withOpacity(0.55),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: _isSavingDiary
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _diarySaved
                          ? Icons.check_circle_outline_rounded
                          : Icons.save_outlined,
                    ),
              label: Text(
                _isSavingDiary
                    ? 'Salvataggio...'
                    : _diarySaved
                        ? 'Diario salvato'
                        : 'Salva diario',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard() {
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
          _sectionHeader(
            icon: Icons.campaign_outlined,
            title: 'Segnalazione al Comune',
            subtitle: _reportSent
                ? 'Segnalazione già inviata'
                : 'Aiuta a migliorare il territorio',
            color: green,
          ),
          const SizedBox(height: 16),
          const Text(
            'Categoria',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: _inputDecoration(),
            items: _reportCategories.map((category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: _reportSent
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedCategory = value;
                    });
                  },
          ),
          const SizedBox(height: 14),
          const Text(
            'La tua segnalazione',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _reportCtrl,
            maxLength: 300,
            maxLines: 3,
            enabled: !_reportSent,
            decoration: _inputDecoration(
              hint: 'Descrivi il problema o il suggerimento per il Comune...',
            ),
          ),
          const SizedBox(height: 12),
          if (_reportSent)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: green,
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Segnalazione inviata',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  width: 56,
                  child: ElevatedButton(
                    onPressed: _isDeletingReport ? null : _deleteReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dangerRed,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: dangerRed.withOpacity(0.55),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isDeletingReport
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 25,
                          ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSendingReport ? null : _sendReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primaryBlue.withOpacity(0.55),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: _isSendingReport
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _isSendingReport
                      ? 'Invio in corso...'
                      : 'Invia segnalazione',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: darkBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      counterStyle: const TextStyle(
        color: Color(0xFF8A94A6),
        fontSize: 11,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: primaryBlue,
          width: 1.4,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 17,
            color: Color(0xFF8A94A6),
          ),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Il diario resta personale. Le segnalazioni, invece, possono essere inviate al Comune per migliorare la gestione del luogo.',
              style: TextStyle(
                color: Color(0xFF8A94A6),
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
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
  final String imageUrl;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _PhotoThumbnail({
    required this.imageUrl,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.network(
                imageUrl,
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDEBFF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFF005A8D),
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                height: 20,
                width: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.red,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoAddButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _PhotoAddButton({
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(
            color: const Color(0xFFD1D5DB),
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF005A8D),
                  ),
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF6B7280),
                    size: 22,
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Aggiungi',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}