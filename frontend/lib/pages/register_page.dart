import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../widgets/easytour_header.dart';
import 'search_page.dart';
import 'dashboard_page.dart';

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
  static const Color lightBackground = Color(0xFFF7FAFC);

  // "TURISTA" oppure "OPERATORE_COMUNALE"
  String ruoloScelto = 'TURISTA';

  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Campi specifici operatore comunale
  final nomeComuneController = TextEditingController();
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
          MaterialPageRoute(builder: (_) => DashboardPage(user: result.user)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SearchPage()),
        );
      }
    } catch (e) {
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
      backgroundColor: lightBackground,
      body: Column(
        children: [
          const EasyTourHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Crea un account',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Selettore ruolo
                  _buildRoleSelector(),
                  const SizedBox(height: 22),

                  // Campi comuni
                  TextField(
                    controller: nomeController,
                    decoration: _dec(
                      isOperatore ? 'Nome referente' : 'Nome',
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dec(
                      isOperatore ? 'Email istituzionale' : 'Email',
                      Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: _dec('Password', Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(
                          () => obscurePassword = !obscurePassword,
                        ),
                      ),
                    ),
                  ),

                  // Campi specifici operatore comunale
                  if (isOperatore) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: nomeComuneController,
                      decoration: _dec('Nome del Comune', Icons.location_city),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: ruoloReferenteController,
                      decoration: _dec(
                        'Ruolo del referente',
                        Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: metodoPagamentoController,
                      decoration: _dec(
                        'Metodo di pagamento',
                        Icons.credit_card,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Accettazione condizioni
                  Row(
                    children: [
                      Checkbox(
                        value: accettaCondizioni,
                        activeColor: primaryBlue,
                        onChanged: (v) => setState(
                          () => accettaCondizioni = v ?? false,
                        ),
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Hai già un account? Accedi',
                        style: TextStyle(color: orange),
                      ),
                    ),
                  ),
                ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
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
        onTap: () => setState(() => ruoloScelto = value),
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

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryBlue),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryBlue, width: 1.6),
      ),
    );
  }
}
