import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
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
  final _loginEmailController = TextEditingController();
  final _loginPassController = TextEditingController();

  // Register controllers
  final _regNameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regOtpController = TextEditingController();
  final _regPassController = TextEditingController();
  final _regConfirmPassController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // OTP state
  bool _isSendingOtp = false;
  bool _otpSent = false;
  bool _isVerifyingOtp = false;
  bool _isEmailVerified = false;
  String? _verificationToken;
  String? _otpStatusMessage;
  String? _debugOtpCode;

  // Resend countdown
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPassController.dispose();
    _regNameController.dispose();
    _regPhoneController.dispose();
    _regEmailController.dispose();
    _regOtpController.dispose();
    _regPassController.dispose();
    _regConfirmPassController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final email = _regEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid Mail ID (Email) before requesting OTP.');
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
      _otpStatusMessage = null;
    });

    try {
      final res = await ApiService.sendOtp(
        email: email,
        name: _regNameController.text.trim().isNotEmpty ? _regNameController.text.trim() : null,
      );

      setState(() {
        _isSendingOtp = false;
        _otpSent = true;
        _debugOtpCode = res.debugOtp;
        _otpStatusMessage = res.message;
        if (res.debugOtp != null && res.debugOtp!.isNotEmpty) {
          _regOtpController.text = res.debugOtp!;
        }
      });
      _startCountdown();
    } catch (e) {
      setState(() {
        _isSendingOtp = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    final email = _regEmailController.text.trim();
    final otp = _regOtpController.text.trim();

    if (otp.isEmpty) {
      setState(() => _errorMessage = 'Please enter the 6-digit OTP code sent to your email.');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.verifyOtp(email: email, otp: otp);
      setState(() {
        _isVerifyingOtp = false;
        _isEmailVerified = true;
        _verificationToken = res.verificationToken;
        _otpStatusMessage = '✅ Mail ID verified successfully!';
      });
    } catch (e) {
      setState(() {
        _isVerifyingOtp = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleLogin() async {
    final email = _loginEmailController.text.trim();
    final pass = _loginPassController.text;

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Mail ID and Password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.loginFarmer(email, pass);
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
    final phone = _regPhoneController.text.trim();
    final email = _regEmailController.text.trim();
    final pass = _regPassController.text;
    final confirmPass = _regConfirmPassController.text;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Full Name.');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Mobile Number.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Mail ID.');
      return;
    }
    if (!_isEmailVerified) {
      setState(() => _errorMessage = 'Please verify your Mail ID with the OTP code first.');
      return;
    }
    if (pass.isEmpty || pass.length < 4) {
      setState(() => _errorMessage = 'Password must be at least 4 characters.');
      return;
    }
    if (pass != confirmPass) {
      setState(() => _errorMessage = 'Passwords do not match. Please verify Confirm Password.');
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
        phone: phone,
        password: pass,
        confirmPassword: confirmPass,
        verificationToken: _verificationToken,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
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
                    child: Text('🌾', style: TextStyle(fontSize: 32)),
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
                  style: TextStyle(color: AgriColors.emerald400, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Multilingual Advisory & Requirement Analysis Platform',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AgriColors.slate400, fontSize: 12),
                ),
                const SizedBox(height: 20),

                // Card Container
                Container(
                  decoration: BoxDecoration(
                    color: AgriColors.slate900,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1e293b)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 24,
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
                            Tab(text: '🔑 Farmer Sign In'),
                            Tab(text: '📝 Register Account'),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              const SizedBox(height: 14),
                            ],

                            AnimatedBuilder(
                              animation: _tabController,
                              builder: (context, _) {
                                return _tabController.index == 0
                                    ? _buildLoginForm()
                                    : _buildRegisterForm();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),


                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Navigate to admin
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

  // ─── LOGIN FORM (Mail ID + Password only) ──────────────────────────────────
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Mail ID / மின்னஞ்சல்',
            hintText: 'e.g. murugesan@agrimind.ai',
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
            prefixIcon: const Icon(Icons.email_outlined, color: AgriColors.emerald500, size: 18),
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
            labelText: 'Password / கடவுச்சொல்',
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
        const SizedBox(height: 20),
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
              : const Text('Sign In / உள்நுழைக', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ─── REGISTER FORM (Name, Mobile, Mail ID + OTP, Create Pass, Confirm Pass) ─
  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Full Name
        TextField(
          controller: _regNameController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Full Name / முழு பெயர்',
            prefixIcon: const Icon(Icons.badge_outlined, color: AgriColors.emerald500, size: 18),
            filled: true,
            fillColor: AgriColors.slate950,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
          ),
        ),
        const SizedBox(height: 10),

        // 2. Mobile Number
        TextField(
          controller: _regPhoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Mobile Number / கைபேசி எண்',
            hintText: 'e.g. +91 98765 43210',
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
            prefixIcon: const Icon(Icons.phone_outlined, color: AgriColors.emerald500, size: 18),
            filled: true,
            fillColor: AgriColors.slate950,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
          ),
        ),
        const SizedBox(height: 10),

        // 3. Mail ID + "Send OTP" Button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _regEmailController,
                enabled: !_isEmailVerified,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Mail ID / மின்னஞ்சல்',
                  hintText: 'e.g. farmer@gmail.com',
                  hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                  prefixIcon: const Icon(Icons.email_outlined, color: AgriColors.emerald500, size: 18),
                  suffixIcon: _isEmailVerified
                      ? const Icon(Icons.verified, color: AgriColors.emerald400, size: 20)
                      : null,
                  filled: true,
                  fillColor: _isEmailVerified ? const Color(0xFF064e3b).withValues(alpha: 0.3) : AgriColors.slate950,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: (_isSendingOtp || _isEmailVerified || _resendCountdown > 0)
                    ? null
                    : _handleSendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEmailVerified ? Colors.grey : AgriColors.emerald700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSendingOtp
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isEmailVerified
                            ? 'Verified'
                            : _resendCountdown > 0
                                ? 'Resend (${_resendCountdown}s)'
                                : (_otpSent ? 'Resend OTP' : 'Send OTP'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),

        // OTP verification section
        if (_otpSent && !_isEmailVerified) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _regOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 4, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'Enter 6-Digit OTP / குறியீடு',
                    hintText: '123456',
                    hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12, letterSpacing: 1),
                    prefixIcon: const Icon(Icons.pin_outlined, color: AgriColors.emerald500, size: 18),
                    filled: true,
                    fillColor: AgriColors.slate950,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isVerifyingOtp ? null : _handleVerifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AgriColors.emerald600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isVerifyingOtp
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Verify OTP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],

        // Status or Dev OTP message
        if (_otpStatusMessage != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isEmailVerified ? const Color(0xFF064e3b).withValues(alpha: 0.3) : const Color(0xFF1e293b),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _isEmailVerified ? AgriColors.emerald500 : const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Icon(_isEmailVerified ? Icons.check_circle : Icons.info_outline, size: 14, color: _isEmailVerified ? AgriColors.emerald400 : Colors.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _otpStatusMessage!,
                    style: TextStyle(fontSize: 11, color: _isEmailVerified ? AgriColors.emerald300 : Colors.white70),
                  ),
                ),
                if (_debugOtpCode != null && !_isEmailVerified) ...[
                  InkWell(
                    onTap: () {
                      _regOtpController.text = _debugOtpCode!;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber.shade900, borderRadius: BorderRadius.circular(4)),
                      child: Text('Fill: $_debugOtpCode', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

        // 4. Create Password
        TextField(
          controller: _regPassController,
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Create Password / கடவுச்சொல்',
            hintText: 'Minimum 4 characters',
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
            prefixIcon: const Icon(Icons.lock_outline, color: AgriColors.emerald500, size: 18),
            filled: true,
            fillColor: AgriColors.slate950,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
          ),
        ),
        const SizedBox(height: 10),

        // 5. Confirm Password
        TextField(
          controller: _regConfirmPassController,
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Confirm Password / உறுதிப்படுத்தவும்',
            hintText: 'Re-enter password',
            hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
            prefixIcon: const Icon(Icons.lock_reset, color: AgriColors.emerald500, size: 18),
            filled: true,
            fillColor: AgriColors.slate950,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
          ),
        ),

        const SizedBox(height: 18),

        // 6. Submit Button
        ElevatedButton(
          onPressed: (_isLoading || !_isEmailVerified) ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: AgriColors.emerald600,
            disabledBackgroundColor: const Color(0xFF1e293b),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 2,
          ),
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(
                  _isEmailVerified ? 'Create Farmer Account / கணக்கை உருவாக்கவும்' : 'Verify Email OTP to Continue',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
