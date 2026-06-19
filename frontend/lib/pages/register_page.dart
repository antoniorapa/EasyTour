import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/easytour_header.dart';
import 'dashboard_utente.dart';
import 'dashboard_page.dart';

/// RegisterPage — versione 2: HERO.
/// Stesso linguaggio visivo della LoginPage: sfondo blu che continua la fascia
/// dell'header con onda, titolo bianco in alto e il form dentro una card
/// bianca arrotondata con ombra che "sale" sopra l'onda. Mobile-first.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final ApiService apiService = ApiService();

  static const Color primaryBlue = Color(0xFF005A8D);
  static const Color darkBlue = Color(0xFF003F63);
  static const Color orange = Color(0xFFF58A00);

  // "TURISTA" oppure "OPERATORE_COMUNALE"
  String ruoloScelto = 'TURISTA';

  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Campi specifici operatore comunale
  final nomeComuneController = TextEditingController();
  final codiceAttivazioneController = TextEditingController();
  final ruoloReferenteController = TextEditingController();
  final metodoPagamentoController = TextEditingController();

  bool accettaCondizioni = false;
  bool isLoading = false;
  bool obscurePassword = true;
  String? errorMessage;

  bool get isOperatore => ruoloScelto == 'OPERATORE_COMUNALE';

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    passwordController.dispose();
    nomeComuneController.dispose();
    codiceAttivazioneController.dispose();
    ruoloReferenteController.dispose();
    metodoPagamentoController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final nome = nomeController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (nome.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Compila nome, email e password');
      return;
    }

    if (!accettaCondizioni) {
      setState(() => errorMessage = 'Devi accettare le condizioni del servizio');
      return;
    }

    if (isOperatore && nomeComuneController.text.trim().isEmpty) {
      setState(() => errorMessage = 'Indica il nome del Comune');
      return;
    }

    if (isOperatore && codiceAttivazioneController.text.trim().isEmpty) {
      setState(() => errorMessage = 'Inserisci il codice di attivazione del Comune');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final AuthResult result;

      if (isOperatore) {
        result = await apiService.registerMunicipality(
          nome: nome,
          email: email,
          password: password,
          nomeComune: nomeComuneController.text.trim(),
          codiceAttivazione: codiceAttivazioneController.text.trim(),
          ruoloReferente: ruoloReferenteController.text.trim(),
          metodoPagamento: metodoPagamentoController.text.trim(),
          accettaCondizioni: accettaCondizioni,
        );
      } else {
        result = await apiService.registerTourist(
          nome: nome,
          email: email,
          password: password,
          accettaCondizioni: accettaCondizioni,
        );
      }

      if (!mounted) return;

      // Dopo la registrazione l'utente è già autenticato: redirect per ruolo.
      if (result.user.isOperatore) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DashboardPage(user: result.user, token: result.token)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DashboardUtente(user: result.user, token: result.token)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      body: Column(
        children: [
          const EasyTourHeader(),
          Expanded(
            child: Container(
              color: primaryBlue,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 16),
                      child: Text(
                        'Crea un account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    // Card bianca col form.
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Inserisci i tuoi dati per iniziare',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Selettore ruolo
                          _buildRoleSelector(),
                          const SizedBox(height: 18),

                          // Campi comuni
                          TextField(
                            controller: nomeController,
                            enabled: !isLoading,
                            textInputAction: TextInputAction.next,
                            decoration: _filledDecoration(
                              isOperatore ? 'Nome referente' : 'Nome',
                              Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !isLoading,
                            textInputAction: TextInputAction.next,
                            decoration: _filledDecoration(
                              isOperatore ? 'Email istituzionale' : 'Email',
                              Icons.email_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            enabled: !isLoading,
                            decoration: _filledDecoration(
                              'Password',
                              Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: isLoading
                                    ? null
                                    : () => setState(() =>
                                        obscurePassword = !obscurePassword),
                              ),
                            ),
                          ),

                          // Campi specifici operatore comunale
                          if (isOperatore) ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: nomeComuneController,
                              enabled: !isLoading,
                              decoration: _filledDecoration(
                                  'Nome del Comune', Icons.location_city),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: codiceAttivazioneController,
                              enabled: !isLoading,
                              decoration: _filledDecoration(
                                'Codice di attivazione',
                                Icons.vpn_key_outlined,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: ruoloReferenteController,
                              enabled: !isLoading,
                              decoration: _filledDecoration(
                                'Ruolo del referente',
                                Icons.badge_outlined,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: metodoPagamentoController,
                              enabled: !isLoading,
                              decoration: _filledDecoration(
                                'Metodo di pagamento',
                                Icons.credit_card,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Accettazione condizioni
                          Row(
                            children: [
                              Checkbox(
                                value: accettaCondizioni,
                                activeColor: primaryBlue,
                                onChanged: isLoading
                                    ? null
                                    : (v) => setState(
                                        () => accettaCondizioni = v ?? false),
                              ),
                              Expanded(
                                child: Text(
                                  'Accetto le condizioni del servizio',
                                  style: TextStyle(color: Colors.grey[800]),
                                ),
                              ),
                            ],
                          ),

                          if (errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _errorBox(errorMessage!),
                          ],

                          const SizedBox(height: 24),

                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: orange,
                                disabledBackgroundColor:
                                    orange.withOpacity(0.5),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Registrati',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Hai già un account? ',
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.85)),
                        ),
                        GestureDetector(
                          onTap: isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(
                            'Accedi',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                              decorationColor: orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _roleTab('Turista', 'TURISTA'),
          _roleTab('Operatore comunale', 'OPERATORE_COMUNALE'),
        ],
      ),
    );
  }

  Widget _roleTab(String label, String value) {
    final selected = ruoloScelto == value;
    return Expanded(
      child: GestureDetector(
        onTap: isLoading ? null : () => setState(() => ruoloScelto = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  InputDecoration _filledDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryBlue),
      filled: true,
      fillColor: const Color(0xFFF2F6F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryBlue, width: 1.6),
      ),
    );
  }
}