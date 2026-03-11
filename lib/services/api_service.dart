import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Storage for tokens
  final _storage = const FlutterSecureStorage();

  // ==================== CONFIGURATION ====================

  // Base URL - Change this based on your environment
  static const String _baseUrl = 'http://192.168.100.25:5000'; // Your computer IP

  // Alternative environments (uncomment as needed)
  // static const String _baseUrl = 'http://10.0.2.2:5000'; // For Android emulator
  // static const String _baseUrl = 'http://localhost:5000'; // For iOS simulator

  // ==================== API ENDPOINTS ====================

// Auth Endpoints
  static const String _loginEndpoint = '/api/auth/login';
  static const String _registerEndpoint = '/api/auth/register';
  static const String _meEndpoint = '/api/auth/me';
  static const String _refreshTokenEndpoint = '/api/auth/refresh-token';
  static const String _changePasswordEndpoint = '/api/auth/change-password';
  static const String _authProfileEndpoint = '/api/auth/profile';

// User Endpoints (Admin only)
  static const String _usersEndpoint = '/api/users';
  static const String _adminUserProfileEndpoint = '/api/users/profile';

  // Loan Endpoints
  static const String _loansEndpoint = '/api/loans';

  // Headers
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _storage.read(key: 'token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // ==================== AUTH SERVICES ====================

  /// Login user with email and password
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_loginEndpoint'),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode({
          'email': email.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        // Store tokens
        await _storage.write(key: 'token', value: data['data']['token']);
        await _storage.write(key: 'refreshToken', value: data['data']['refreshToken']);

        // Store user data
        final user = UserModel.fromJson(data['data']['user']);
        await _storage.write(key: 'user', value: json.encode(user.toJson()));

        return {
          'success': true,
          'user': user,
          'role': data['data']['role'],
          'redirect': data['data']['redirect'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Register new user (borrower by default)
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_registerEndpoint'),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode({
          'name': name.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'password': password,
          'role': 'borrower', // Default role
        }),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success']) {
        return {
          'success': true,
          'message': 'Account created successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Refresh access token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refreshToken');
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl$_refreshTokenEndpoint'),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        await _storage.write(key: 'token', value: data['token']);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get current user data from API
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_meEndpoint'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final user = UserModel.fromJson(data['data']);
        await _storage.write(key: 'user', value: json.encode(user.toJson()));

        return {
          'success': true,
          'user': user,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get user',
        };
      }
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Change password
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl$_changePasswordEndpoint'),
        headers: await _getHeaders(),
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        // Update stored token
        await _storage.write(key: 'token', value: data['token']);

        return {
          'success': true,
          'message': 'Password changed successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to change password',
        };
      }
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _storage.deleteAll();
  }

  /// Get stored user
  Future<UserModel?> getStoredUser() async {
    final userString = await _storage.read(key: 'user');
    if (userString != null) {
      try {
        final userJson = json.decode(userString);
        return UserModel.fromJson(userJson);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: 'token');
    return token != null;
  }

  /// Get auth token
  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  // ==================== LOAN SERVICES ====================
  /// Get user's loans with pagination (UPDATED to include installment info)
  Future<Map<String, dynamic>> getUserLoans({
    int limit = 10,
    int page = 1,
    String? status,
  }) async {
    try {
      // Get current user to get their ID
      final user = await getStoredUser();
      if (user == null) {
        return {
          'success': false,
          'message': 'User not authenticated',
          'loans': [],
        };
      }

      print('Fetching loans for user: ${user.id}'); // Debug log

      // Build URL with user filter
      String url = '$_baseUrl$_loansEndpoint?limit=$limit&page=$page&sortBy=createdAt&sortOrder=desc&borrower=${user.id}';

      if (status != null && status != 'all') {
        url += '&status=$status';
      }

      print('Request URL: $url'); // Debug log

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        // Process loans to ensure installment information is available
        List<dynamic> loans = data['data'] ?? [];

        // Calculate next installment amount for each active loan
        for (var loan in loans) {
          if (loan['status'] == 'active') {
            // Calculate installment amount if not present
            if (loan['installmentAmount'] == null) {
              final amount = (loan['amount'] is int)
                  ? (loan['amount'] as int).toDouble()
                  : (loan['amount'] as double?) ?? 0.0;
              final term = loan['term'] ?? 1;
              loan['installmentAmount'] = amount / term;
            }

            // Calculate next installment amount based on paid amount
            final amount = (loan['amount'] is int)
                ? (loan['amount'] as int).toDouble()
                : (loan['amount'] as double?) ?? 0.0;
            final paidAmount = (loan['paidAmount'] is int)
                ? (loan['paidAmount'] as int).toDouble()
                : (loan['paidAmount'] as double?) ?? 0.0;
            final installmentAmount = loan['installmentAmount'] ?? (amount / (loan['term'] ?? 1));

            // If loan is partially paid, next installment might be less
            final remainingAmount = amount - paidAmount;
            if (remainingAmount < installmentAmount) {
              loan['nextInstallment'] = remainingAmount;
            } else {
              loan['nextInstallment'] = installmentAmount;
            }

            loan['remainingAmount'] = remainingAmount;
          }
        }

        return {
          'success': true,
          'loans': loans,
          'pagination': data['pagination'] ?? {},
        };
      } else {
        print('API Error: ${data['message']}');
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get loans',
          'loans': [],
        };
      }
    } catch (e) {
      print('Exception in getUserLoans: $e');
      return {
        'success': false,
        'message': 'Failed to load loans',
        'loans': [],
        'error': e.toString(),
      };
    }
  }

  /// Get single loan details by ID
  Future<Map<String, dynamic>> getLoanDetails(String loanId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_loansEndpoint/$loanId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'loan': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get loan details',
        };
      }
    } catch (e) {
      return _handleError(e);
    }
  }


  /// Record a payment for a loan
  Future<Map<String, dynamic>> recordPayment(String loanId, Map<String, dynamic> paymentData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_loansEndpoint/$loanId/payments'),
        headers: await _getHeaders(),
        body: json.encode(paymentData),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'payment': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to record payment',
        };
      }
    } catch (e) {
      return _handleError(e);
    }
  }

  // ==================== USER/PROFILE SERVICES ====================

  /// Update user profile (for authenticated users to update their own profile)
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
    Map<String, dynamic>? profile,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;
      if (profile != null) updateData['profile'] = profile;

      final response = await http.put(
        Uri.parse('$_baseUrl/api/auth/profile'), // Use the auth endpoint directly
        headers: await _getHeaders(),
        body: json.encode(updateData),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        // Update stored user data
        final user = UserModel.fromJson(data['data']);
        await _storage.write(key: 'user', value: json.encode(user.toJson()));

        return {
          'success': true,
          'user': user,
          'message': 'Profile updated successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      return _handleError(e);
    }
  }

// Add these to your ApiService class in api_service.dart

// ==================== PAYMENT SERVICES (NEW) ====================

  /// Process a loan payment through WaafiPay
  Future<Map<String, dynamic>> processLoanPayment({
    required String loanId,
    required double amount,
    required String paymentMethod,
    required String phoneNumber,
    required String invoiceId,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated. Please login again.'
        };
      }

      print('Processing payment: $amount for loan: $loanId'); // Debug log

      final response = await http.post(
        Uri.parse('$_baseUrl/api/payments/process'),
        headers: await _getHeaders(),
        body: json.encode({
          'loanId': loanId,
          'amount': amount,
          'paymentMethod': paymentMethod,
          'phoneNumber': phoneNumber,
          'invoiceId': invoiceId,
        }),
      ).timeout(const Duration(seconds: 60)); // Longer timeout for payment processing

      final data = json.decode(response.body);
      print('Payment response: ${response.body}'); // Debug log

      return data;
    } catch (e) {
      print('Error processing payment: $e');
      if (e.toString().contains('Timeout')) {
        return {
          'success': false,
          'message': 'Payment timeout. Please check your connection and try again.',
        };
      }
      return {
        'success': false,
        'message': 'Failed to process payment: ${e.toString()}',
      };
    }
  }

  /// Get user's payment history
  Future<Map<String, dynamic>> getUserPaymentHistory({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
          'payments': [],
        };
      }

      String url = '$_baseUrl/api/payments/history?page=$page&limit=$limit';
      if (status != null && status != 'All') {
        url += '&status=${status.toLowerCase()}';
      }

      print('Fetching payment history: $url'); // Debug log

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'payments': data['payments'] ?? [],
          'pagination': data['pagination'] ?? {
            'page': page,
            'limit': limit,
            'total': 0,
            'pages': 1
          },
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get payment history',
          'payments': [],
        };
      }
    } catch (e) {
      print('Error fetching payment history: $e');
      return {
        'success': false,
        'message': 'Failed to load payment history',
        'payments': [],
        'error': e.toString(),
      };
    }
  }

  /// Get payment statistics
  Future<Map<String, dynamic>> getPaymentStats() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
          'stats': {
            'totalPayments': 0,
            'successfulCount': 0,
            'pendingCount': 0,
            'failedCount': 0,
            'totalAmount': 0.0,
          },
        };
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/payments/stats'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'stats': data['stats'] ?? {
            'totalPayments': 0,
            'successfulCount': 0,
            'pendingCount': 0,
            'failedCount': 0,
            'totalAmount': 0.0,
          },
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get payment stats',
          'stats': {
            'totalPayments': 0,
            'successfulCount': 0,
            'pendingCount': 0,
            'failedCount': 0,
            'totalAmount': 0.0,
          },
        };
      }
    } catch (e) {
      print('Error fetching payment stats: $e');
      return {
        'success': false,
        'message': 'Failed to load payment statistics',
        'stats': {
          'totalPayments': 0,
          'successfulCount': 0,
          'pendingCount': 0,
          'failedCount': 0,
          'totalAmount': 0.0,
        },
      };
    }
  }

  /// Get single payment details by ID
  Future<Map<String, dynamic>> getPaymentDetails(String paymentId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/payments/$paymentId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'payment': data['payment'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get payment details',
        };
      }
    } catch (e) {
      print('Error fetching payment details: $e');
      return {
        'success': false,
        'message': 'Failed to load payment details',
      };
    }
  }

  /// Generate a unique invoice ID for payment
  String generateInvoiceId() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  /// Validate phone number format for Somali numbers
  bool isValidSomaliPhone(String phone, String paymentMethod) {
    // Remove any non-digit characters
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    if (paymentMethod == 'EVC Plus') {
      // EVC Plus numbers should start with 2526 and be 12 digits total (including 252)
      return RegExp(r'^2526\d{7,8}$').hasMatch(cleanPhone);
    } else if (paymentMethod == 'E-Dahab') {
      // E-Dahab numbers should start with 25268 and be 12-13 digits total
      return RegExp(r'^25268\d{7,8}$').hasMatch(cleanPhone);
    }

    return false;
  }

  /// Format phone number to ensure it has the correct prefix
  String formatPhoneNumber(String phone, String paymentMethod) {
    // Remove any non-digit characters
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    // If it already starts with 252, return as is
    if (cleanPhone.startsWith('252')) {
      return cleanPhone;
    }

    // Remove leading zero if present
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }

    // Add 252 prefix
    return '252$cleanPhone';
  }

// ==================== PASSWORD RESET SERVICES ====================

  /// Request password reset OTP
  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/forgot-password'),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode({
          'email': email.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      return data;
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Verify OTP
  Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/verify-otp'),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode({
          'email': email.trim(),
          'otp': otp.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      return data;
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Reset password
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/reset-password'),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode({
          'email': email.trim(),
          'resetToken': resetToken,
          'newPassword': newPassword,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      return data;
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Resend OTP
  Future<Map<String, dynamic>> resendOTP({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/resend-otp'),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode({
          'email': email.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      return data;
    } catch (e) {
      return _handleError(e);
    }
  }

  // ==================== HELPER METHODS ====================

  /// Handle errors consistently
  Map<String, dynamic> _handleError(dynamic error) {
    if (error is http.ClientException) {
      return {
        'success': false,
        'message': 'Network error. Please check your connection.',
        'error': error.toString(),
      };
    } else if (error.toString().contains('Timeout')) {
      return {
        'success': false,
        'message': 'Connection timeout. Server is not responding.',
        'error': error.toString(),
      };
    } else {
      return {
        'success': false,
        'message': 'An unexpected error occurred.',
        'error': error.toString(),
      };
    }
  }

  // Add this to your ApiService class in api_service.dart
// Place it after the Loan Services section and before the User/Profile Services

// ==================== GUARANTOR SERVICES ====================

  /// Get guarantor dashboard statistics
  Future<Map<String, dynamic>> getGuarantorStats() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
          'data': null,
        };
      }

      print('📊 Fetching guarantor stats...'); // Debug log

      final response = await http.get(
        Uri.parse('$_baseUrl/api/guarantor/stats'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      print('📊 Stats response: ${response.body}'); // Debug log

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'data': data['data'] ?? {
            'totalGuaranteed': 0,
            'activeLoans': 0,
            'overdueLoans': 0,
            'completedLoans': 0,
            'totalAmount': 0.0,
            'atRiskAmount': 0.0,
            'paidAmount': 0.0,
          },
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get guarantor stats',
          'data': null,
        };
      }
    } catch (e) {
      print('❌ Error fetching guarantor stats: $e');
      return _handleError(e);
    }
  }

  /// Get all loans where user is guarantor
  Future<Map<String, dynamic>> getGuarantorLoans({
    int page = 1,
    int limit = 10,
    String? status,
    String? search,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
          'data': [],
          'pagination': null,
        };
      }

      // Build URL with query parameters
      String url = '$_baseUrl/api/guarantor/loans?page=$page&limit=$limit';

      if (status != null && status != 'All' && status != 'all') {
        url += '&status=${status.toLowerCase()}';
      }

      if (search != null && search.isNotEmpty) {
        url += '&search=$search';
      }

      print('📋 Fetching guarantor loans: $url'); // Debug log

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      print('📋 Loans response: ${response.body}'); // Debug log

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'data': data['data'] ?? [],
          'pagination': data['pagination'] ?? {
            'page': page,
            'limit': limit,
            'total': 0,
            'pages': 1
          },
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get guaranteed loans',
          'data': [],
          'pagination': null,
        };
      }
    } catch (e) {
      print('❌ Error fetching guarantor loans: $e');
      return _handleError(e);
    }
  }

  /// Get single loan details by ID (for guarantor)
  Future<Map<String, dynamic>> getGuarantorLoanDetails(String loanId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
          'data': null,
        };
      }

      print('🔍 Fetching guarantor loan details for ID: $loanId'); // Debug log

      final response = await http.get(
        Uri.parse('$_baseUrl/api/guarantor/loans/$loanId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      print('🔍 Loan details response: ${response.body}'); // Debug log

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get loan details',
          'data': null,
        };
      }
    } catch (e) {
      print('❌ Error fetching guarantor loan details: $e');
      return _handleError(e);
    }
  }

  /// Get loan payment schedule (for guarantor)
  Future<Map<String, dynamic>> getGuarantorLoanSchedule(String loanId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
          'data': null,
        };
      }

      print('📅 Fetching loan schedule for ID: $loanId'); // Debug log

      final response = await http.get(
        Uri.parse('$_baseUrl/api/guarantor/loans/$loanId/schedule'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      print('📅 Schedule response: ${response.body}'); // Debug log

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'data': data['data'] ?? {'schedule': []},
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get loan schedule',
          'data': null,
        };
      }
    } catch (e) {
      print('❌ Error fetching loan schedule: $e');
      return _handleError(e);
    }
  }

  /// Get loan payment history (for guarantor)
  Future<Map<String, dynamic>> getGuarantorLoanPayments(String loanId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
          'data': null,
        };
      }

      print('💰 Fetching loan payments for ID: $loanId'); // Debug log

      final response = await http.get(
        Uri.parse('$_baseUrl/api/guarantor/loans/$loanId/payments'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      print('💰 Payments response: ${response.body}'); // Debug log

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'data': data['data'] ?? {'payments': []},
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get loan payments',
          'data': null,
        };
      }
    } catch (e) {
      print('❌ Error fetching loan payments: $e');
      return _handleError(e);
    }
  }

  /// Get guarantor notifications
  Future<Map<String, dynamic>> getGuarantorNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
          'data': [],
          'pagination': null,
        };
      }

      String url = '$_baseUrl/api/guarantor/notifications?page=$page&limit=$limit';

      print('🔔 Fetching guarantor notifications: $url'); // Debug log

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      print('🔔 Notifications response: ${response.body}'); // Debug log

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'data': data['data'] ?? [],
          'pagination': data['pagination'] ?? {
            'page': page,
            'limit': limit,
            'total': 0,
            'pages': 1
          },
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get notifications',
          'data': [],
          'pagination': null,
        };
      }
    } catch (e) {
      print('❌ Error fetching guarantor notifications: $e');
      return _handleError(e);
    }
  }

  /// Mark notification as read
  Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('✅ Marking notification as read: $notificationId'); // Debug log

      final response = await http.put(
        Uri.parse('$_baseUrl/api/guarantor/notifications/$notificationId/read'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);
      print('✅ Mark read response: ${response.body}'); // Debug log

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'message': data['message'] ?? 'Notification marked as read',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to mark notification as read',
        };
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      return _handleError(e);
    }
  }


  /// Get base URL (useful for debugging)
  static String get baseUrl => _baseUrl;
}