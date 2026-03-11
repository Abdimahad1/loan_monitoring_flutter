// lib/auth_screens/verify_otp_screen.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_constants.dart';
import '../widgets/gradient_button.dart';
import 'reset_password_screen.dart';

class VerifyOTPScreen extends StatefulWidget {
  final String email;

  const VerifyOTPScreen({super.key, required this.email});

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
        (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  int _secondsRemaining = 60;
  bool _canResend = false;
  String? _resetToken;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _canResend = false;
    _secondsRemaining = 60;

    Future.delayed(const Duration(seconds: 1), _tick);
  }

  void _tick() {
    if (mounted) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
          Future.delayed(const Duration(seconds: 1), _tick);
        } else {
          _canResend = true;
        }
      });
    }
  }

  String get _otpCode {
    return _otpControllers.map((c) => c.text).join();
  }

  Future<void> _verifyOTP() async {
    if (_otpCode.length != 6) {
      _showError('Please enter complete 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.verifyOTP(
        email: widget.email,
        otp: _otpCode,
      );

      if (result['success']) {
        setState(() {
          _resetToken = result['data']['resetToken'];
        });

        // Navigate to reset password screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              email: widget.email,
              resetToken: _resetToken!,
            ),
          ),
        );
      } else {
        _showError(result['message'] ?? 'Invalid OTP');

        // Clear OTP fields on error
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } catch (e) {
      _showError('An error occurred: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);

    try {
      final result = await _apiService.resendOTP(
        email: widget.email,
      );

      if (result['success']) {
        _showSuccess('New OTP sent successfully');
        _startTimer();

        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      } else {
        _showError(result['message'] ?? 'Failed to resend OTP');
      }
    } catch (e) {
      _showError('An error occurred: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sms,
                  size: 40,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the 6-digit code sent to',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                widget.email,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // OTP Fields
              Form(
                key: _formKey,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 45,
                      height: 55,
                      child: TextFormField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.length == 1 && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 24),

              // Timer
              Center(
                child: Text(
                  _canResend
                      ? 'Didn\'t receive code?'
                      : 'Resend code in $_secondsRemaining seconds',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Resend Button
              Center(
                child: TextButton(
                  onPressed: _canResend && !_isLoading ? _resendOTP : null,
                  child: Text(
                    'Resend OTP',
                    style: TextStyle(
                      color: _canResend ? AppColors.primaryGreen : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Verify Button
              GradientButton(
                onPressed: _verifyOTP,
                text: 'Verify OTP',
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}