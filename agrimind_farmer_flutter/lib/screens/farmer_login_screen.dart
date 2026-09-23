import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';
import 'farmer_chat_screen.dart';

class FarmerLoginScreen extends StatefulWidget {
  const FarmerLoginScreen({super.key});

  @override
  State<FarmerLoginScreen> createState() => _FarmerLoginScreenState();
}

class _FarmerLoginScreenState extends State<FarmerLoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login controllers
  final _loginIdController = TextEditingController();
  final _loginPassController = TextEditingController();

  // Register controllers
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regPassController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginIdController.dispose();
    _loginPassController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPhoneController.dispose();
    _regPassController.dispose();
    super.dispose();
  }

  void _demoLogin() {
    _loginIdController.text = 'murugesan@agrimind.ai';
    _loginPassController.text = 'farmer123';
    _handleLogin();
  }

  Future<void> _handleLogin() async {
    final username = _loginIdController.text.trim();
    final pass = _loginPassController.text;

    if (username.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Please enter your mobile number or email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.loginFarmer(username, pass);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FarmerChatScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRegister() async {
    final name = _regNameController.text.trim();
    final email = _regEmailController.text.trim();
    final phone = _regPhoneController.text.trim();
    final pass = _regPassController.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Please fill in Name, Email, and Password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.registerFarmer(
        fullName: name,
        email: email,
        phone: phone.isNotEmpty ? phone : null,
        password: pass,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FarmerChatScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgriColors.slate950,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top Brand Logo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AgriColors.emerald600, AgriColors.emerald500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AgriColors.emerald500.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🌿', style: TextStyle(fontSize: 32)),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'AgriMind',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Farmer Portal · உழவர் தளம்',
                  style: TextStyle(color: AgriColors.emerald400, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bilingual Voice & Text Agricultural Requirement System',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AgriColors.slate400, fontSize: 12),
                ),
                const SizedBox(height: 24),

                // Card Container
                Container(
                  decoration: BoxDecoration(
                    color: AgriColors.slate900,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1e293b)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Tab Bar
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF0a0f1d),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: AgriColors.emerald500,
                          indicatorWeight: 3,
                          labelColor: Colors.white,
                          unselectedLabelColor: AgriColors.slate400,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          tabs: const [
                            Tab(text: '🌾 Farmer Sign In'),
                            Tab(text: '📝 Register New'),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            SizedBox(
                              height: 280,
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildLoginForm(),
                                  _buildRegisterForm(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Quick Demo Account Helper
                OutlinedButton.icon(
                  onPressed: _demoLogin,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AgriColors.emerald300,
                    side: BorderSide(color: AgriColors.emerald500.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.bolt, size: 16, color: AgriColors.emerald400),
                  label: const Text('One-Click Demo Login (Murugesan K.)', style: TextStyle(fontSize: 12)),
                ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    // Navigate to admin
                    final uri = Uri.base.resolve('/admin/');
                    Navigator.of(context).pushNamed('/admin');
                  },
                  child: const Text(
                    '🛡️ Administrator? Go to Admin Portal',
                    style: TextStyle(color: AgriColors.slate400, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginIdController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Mobile Number or Email',
            hintText: 'e.g. murugesan@agrimind.ai or 9876543210',
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
            prefixIcon: const Icon(Icons.person_outline, color: AgriColors.emerald500, size: 18),
            filled: true,
            fillColor: AgriColors.slate950,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _loginPassController,
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
            prefixIcon: const Icon(Icons.lock_outline, color: AgriColors.emerald500, size: 18),
            filled: true,
            fillColor: AgriColors.slate950,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
          ),
          onSubmitted: (_) => _handleLogin(),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AgriColors.emerald600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 2,
          ),
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Sign In to Farmer Portal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _regNameController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Full Name (முழு பெயர்)',
              prefixIcon: const Icon(Icons.badge_outlined, color: AgriColors.emerald500, size: 18),
              filled: true,
              fillColor: AgriColors.slate950,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regEmailController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Email Address',
              prefixIcon: const Icon(Icons.email_outlined, color: AgriColors.emerald500, size: 18),
              filled: true,
              fillColor: AgriColors.slate950,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regPhoneController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Mobile Number (கைபேசி எண்)',
              prefixIcon: const Icon(Icons.phone_outlined, color: AgriColors.emerald500, size: 18),
              filled: true,
              fillColor: AgriColors.slate950,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _regPassController,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Create Password',
              prefixIcon: const Icon(Icons.lock_outline, color: AgriColors.emerald500, size: 18),
              filled: true,
              fillColor: AgriColors.slate950,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: AgriColors.emerald600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create Farmer Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
