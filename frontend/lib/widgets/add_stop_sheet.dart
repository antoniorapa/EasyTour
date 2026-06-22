import 'package:flutter/material.dart';

import '../models/place.dart';
import '../services/api_service.dart';

class AddStopSheet extends StatefulWidget {
  final List<Place> availablePlaces;
  final int numeroGiorni;

  const AddStopSheet({
    super.key,
    required this.availablePlaces,
    required this.numeroGiorni,
  });

  @override
  State<AddStopSheet> createState() => _AddStopSheetState();
}

class _AddStopSheetState extends State<AddStopSheet> {
  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);
  static const Color lightBackground = Color(0xFFF7FAFC);
  static const Color softBlue = Color(0xFFEAF4FA);
  static const Color softOrange = Color(0xFFFFF2DF);

  final ApiService apiService = ApiService();
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  int selectedDay = 1;
  bool isSearching = false;
  late List<Place> results;

  @override
  void initState() {
    super.initState();
    results = List.from(widget.availablePlaces);
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String value) async {
    setState(() => isSearching = true);

    try {
      final cleanQuery = value.trim();

      if (cleanQuery.isEmpty) {
        results = List.from(widget.availablePlaces);
      } else {
        results = await apiService.searchGooglePlacesText(cleanQuery);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nella ricerca: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSearching = false);
    }
  }

  void _selectPlace(Place place) {
    // chiudi la tastiera PRIMA di chiudere il modal
    searchFocusNode.unfocus();
    // restituisci la scelta alla pagina chiamante
    Navigator.pop(context, {'place': place, 'day': selectedDay});
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Colors.black54),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
    );
  }

  String _buildPlaceSubtitle(Place place) {
    final distanceText = place.distanzaKm == null
        ? ''
        : ' • ${place.distanzaKm!.toStringAsFixed(2)} km';

    final reviewText = place.numeroRecensioni > 0
        ? '${place.numeroRecensioni} recensioni'
        : 'recensioni non disponibili';

    final addressText = place.indirizzo == null || place.indirizzo!.isEmpty
        ? ''
        : '\n${place.indirizzo}';

    return '${place.categoria} • $reviewText$distanceText$addressText';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: lightBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D9E2),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Aggiungi tappa',
              style: TextStyle(
                color: darkBlue,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Scegli il giorno e aggiungi una nuova attrazione.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: selectedDay,
              decoration: _inputDecoration('Giorno'),
              items: List.generate(widget.numeroGiorni, (index) {
                final day = index + 1;
                return DropdownMenuItem<int>(
                  value: day,
                  child: Text('Giorno $day'),
                );
              }),
              onChanged: (value) {
                if (value == null) return;
                setState(() => selectedDay = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              decoration: _inputDecoration('Cerca attrazione').copyWith(
                hintText: 'Es. museo, castello, parco...',
                prefixIcon: const Icon(Icons.search_rounded, color: primaryBlue),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: orange),
                  onPressed: () => _runSearch(searchController.text),
                ),
              ),
              onSubmitted: _runSearch,
            ),
            const SizedBox(height: 12),
            if (isSearching)
              const LinearProgressIndicator(
                color: orange,
                backgroundColor: softBlue,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('Nessun risultato trovato.'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final place = results[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            title: Text(
                              place.nome,
                              style: const TextStyle(
                                color: darkBlue,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              _buildPlaceSubtitle(place),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: softOrange,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(Icons.add_rounded, color: orange),
                            ),
                            onTap: () => _selectPlace(place),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}