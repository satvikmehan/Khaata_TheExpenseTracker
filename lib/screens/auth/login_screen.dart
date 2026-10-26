import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Countdown for resend OTP
  int _resendCountdown = 30;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _resendCountdown = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty || rawPhone.length < 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit mobile number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await AuthService.instance.sendOtp(
      rawPhoneNumber: rawPhone,
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isOtpSent = true;
          });
          _startTimer();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = error;
          });
        }
      },
    );
  }

  Future<void> _handleVerifyOtp() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.verifyOtpAndSignIn(
        smsCode: code,
      );
      // Navigation is automatically handled by authStateChanges stream in main.dart
      // If brand new user, GroupsScreen prompts for name immediately upon arrival
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      // Successful sign in automatically triggers authStateChanges in main.dart
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      margin: const EdgeInsets.only(bottom: 20.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
                    ),
                  ),
                  const Text(
                    'Khaata',
                    style: TextStyle(
                      fontSize: 26.0,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Text(
                    _isOtpSent
                        ? 'Enter the 6-digit verification code sent to your phone'
                        : 'Sign in to access your shared expenses',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32.0),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      margin: const EdgeInsets.only(bottom: 20.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 13.0,
                        ),
                      ),
                    ),
                  ],

                  if (!_isOtpSent) ...[
                    // Step 1: Phone Number Input
                    Text(
                      'Mobile Number',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        // Country Code Prefix
                        Container(
                          height: 48.0,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        // Phone input
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            autofocus: false,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleSendOtp(),
                            style: const TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                            decoration: const InputDecoration(
                              hintText: '98765 43210',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20.0),

                    // Send OTP Button
                    SizedBox(
                      height: 48.0,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSendOtp,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Send Verification Code'),
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // "OR" Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 24.0),

                    // Sign in with Google Button
                    SizedBox(
                      height: 48.0,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GoogleLogoIcon(size: 20.0),
                            SizedBox(width: 12.0),
                            Text(
                              'Sign in with Google',
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Step 2: OTP & Profile Name Input
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Phone: +91 ${_phoneController.text.trim()}',
                            style: const TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isOtpSent = false;
                              _otpController.clear();
                              _errorMessage = null;
                            });
                          },
                          child: const Text('Edit Phone'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    Text(
                      '6-Digit OTP',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      maxLength: 6,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleVerifyOtp(),
                      style: const TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6.0,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                      ),
                    ),
                    const SizedBox(height: 28.0),

                    // Verify & Continue Button
                    SizedBox(
                      height: 48.0,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleVerifyOtp,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Verify & Continue'),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Resend code option
                    Center(
                      child: _resendCountdown > 0
                          ? Text(
                              'Resend OTP in ${_resendCountdown}s',
                              style: TextStyle(
                                fontSize: 13.0,
                                color: Colors.grey.shade500,
                              ),
                            )
                          : TextButton(
                              onPressed: _handleSendOtp,
                              child: const Text('Resend Code'),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w * 0.44;
    final strokeWidth = w * 0.20;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Red: top-left (from -135 to -45 deg)
    canvas.drawArc(rect, -3.14159 * 0.75, 3.14159 * 0.5, false, paintRed);
    // Yellow: bottom-left (from 135 to 225 deg)
    canvas.drawArc(rect, 3.14159 * 0.75, 3.14159 * 0.5, false, paintYellow);
    // Green: bottom-right (from 45 to 135 deg)
    canvas.drawArc(rect, 3.14159 * 0.25, 3.14159 * 0.5, false, paintGreen);
    // Blue: top-right and right (from -45 to 45 deg)
    canvas.drawArc(rect, -3.14159 * 0.25, 3.14159 * 0.5, false, paintBlue);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final barRect = Rect.fromLTWH(
      center.dx - strokeWidth * 0.1,
      center.dy - strokeWidth / 2,
      radius + strokeWidth / 2,
      strokeWidth,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoogleLogoIcon extends StatelessWidget {
  final double size;
  const GoogleLogoIcon({super.key, this.size = 20.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}
