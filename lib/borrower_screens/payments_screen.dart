import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/app_constants.dart';
import '../widgets/payment_card.dart';
import 'loan_details_screen.dart';
import 'dart:async';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with SingleTickerProviderStateMixin {
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _isLoading = true;
  bool _isRefreshing = false;

  // Payment processing variables
  bool _isProcessingPayment = false;
  Timer? _countdownTimer;
  int _secondsLeft = 60;

  List<Map<String, dynamic>> _allPayments = [];
  List<Map<String, dynamic>> _activeLoans = [];
  Map<String, dynamic> _stats = {
    'totalPayments': 0,
    'successfulCount': 0,
    'pendingCount': 0,
    'failedCount': 0,
    'totalAmount': 0.0,
  };

  // Payment form variables
  String? _selectedLoanId;
  Map<String, dynamic>? _selectedLoan;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedPaymentMethod = 'EVC Plus';

  // Available payment methods
  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'name': 'EVC Plus',
      'icon': Icons.phone_android,
      'prefix': '2526',
      'image': 'assets/images/evcplus.png',
      'active': true,
      'description': 'Somalilands leading mobile money'
    },
    {
      'name': 'E-Dahab',
      'icon': Icons.phone_iphone,
      'prefix': '25268',
      'image': 'assets/images/edahab.png',
      'active': false,
      'comingSoon': true,
      'description': 'Coming soon - Please use EVC Plus'
    },
  ];

  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // FIXED: Helper method to safely convert any value to double
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    if (value is num) return value.toDouble();
    return 0.0;
  }

  // FIXED: Helper method to safely format amount
  String _formatAmount(dynamic amount) {
    final doubleValue = _toDouble(amount);
    return '\$${doubleValue.toStringAsFixed(2)}';
  }

  // FIXED: Helper method to safely parse date
  DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is DateTime) return date;
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String _getUserFriendlyErrorMessage(String errorMsg, String? responseMsg) {
    final lowerError = errorMsg.toLowerCase();
    final lowerResponse = responseMsg?.toLowerCase() ?? '';

    // Insufficient balance errors
    if (lowerError.contains('insufficient') ||
        lowerError.contains('haraaga') ||
        lowerResponse.contains('haraaga') ||
        lowerError.contains('balance')) {
      return '⚠️ Insufficient Balance\n\nYour EVC Plus account does not have enough money. Please:\n• Check your EVC Plus balance\n• Add funds to your account\n• Try again with sufficient balance';
    }

    // Wrong phone number format
    if (lowerError.contains('phone') || lowerError.contains('format')) {
      return '📱 Invalid Phone Number\n\nPlease enter a valid Somali phone number:\n• EVC Plus: 2526XXXXXXX\n• Make sure it starts with 2526';
    }

    // Network/connection errors
    if (lowerError.contains('timeout') || lowerError.contains('network')) {
      return '🌐 Network Error\n\nUnable to connect to payment service. Please:\n• Check your internet connection\n• Try again in a few moments';
    }

    // Authentication errors
    if (lowerError.contains('auth') || lowerError.contains('login') || lowerError.contains('token')) {
      return '🔐 Session Expired\n\nPlease login again to continue with your payment.';
    }

    // Payment method errors
    if (lowerError.contains('method') || lowerError.contains('evc') || lowerError.contains('edahab')) {
      if (lowerError.contains('coming soon')) {
        return '🕒 E-Dahab Coming Soon\n\nE-Dahab payments are not available yet. Please use EVC Plus for now.';
      }
      return '💳 Payment Method Error\n\nPlease select EVC Plus as your payment method.';
    }

    // Loan related errors
    if (lowerError.contains('loan not found') || lowerError.contains('does not belong')) {
      return '❌ Loan Error\n\nUnable to process payment for this loan. Please contact support if this issue persists.';
    }

    if (lowerError.contains('already fully paid')) {
      return '✅ Loan Already Paid\n\nThis loan has been fully paid. No further payments are needed.';
    }

    if (lowerError.contains('active') || lowerError.contains('overdue')) {
      return '⏳ Loan Status Error\n\nThis loan is not eligible for payment at this time. Please check loan details.';
    }

    if (lowerError.contains('exactly')) {
      final match = RegExp(r'\d+\.?\d*').firstMatch(errorMsg);
      final amount = match?.group(0) ?? '';
      return '💰 Incorrect Amount\n\nPlease pay exactly ${amount.isEmpty ? 'the installment amount' : '\$$amount'} for this loan.';
    }

    // Duplicate payment
    if (lowerError.contains('duplicate')) {
      return '🔄 Duplicate Payment\n\nThis payment has already been processed. Please check your payment history.';
    }

    // Generic error with response message
    if (responseMsg != null && responseMsg.isNotEmpty) {
      if (responseMsg.contains('Haraaga')) {
        return '⚠️ Insufficient Balance\n\nYour EVC Plus account does not have enough money. Please add funds and try again.';
      }
      return '❌ Payment Failed\n\n$responseMsg\n\nPlease try again or contact support.';
    }

    // Default error
    return '❌ Payment Failed\n\nUnable to process your payment. Please try again later or contact support.';
  }

  String _getSuccessMessage(Map<String, dynamic>? data) {
    if (data == null) return 'Payment processed successfully!';

    final remainingAmount = data['remainingAmount'];
    if (remainingAmount != null) {
      final remaining = _toDouble(remainingAmount);
      if (remaining <= 0) {
        return '🎉 Congratulations!\n\nYour loan has been fully paid! Thank you for your timely payments.';
      } else {
        return '✅ Payment Successful!\n\nRemaining balance: ${_formatAmount(remaining)}\nNext payment due soon.';
      }
    }

    return '✅ Payment processed successfully!';
  }

  @override
  void initState() {
    super.initState();
    _loadPayments();
    _loadActiveLoans();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _scrollController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);

    try {
      final user = await _apiService.getStoredUser();
      if (user == null) {
        _showError('Please login to view your payments');
        setState(() => _isLoading = false);
        return;
      }

      // Fetch payment history
      final paymentsResult = await _apiService.getUserPaymentHistory(
        status: _selectedFilter != 'All' ? _selectedFilter : null,
      );

      // Fetch stats separately
      final statsResult = await _apiService.getPaymentStats();

      if (paymentsResult['success']) {
        final payments = paymentsResult['payments'] as List? ?? [];

        // Process payments with safe type conversion
        final List<Map<String, dynamic>> processedPayments = [];
        for (var payment in payments) {
          if (payment is Map<String, dynamic>) {
            // Ensure all numeric values are properly typed
            final processedPayment = Map<String, dynamic>.from(payment);
            processedPayment['displayStatus'] = _mapPaymentStatus(processedPayment['status']);
            processedPayment['amount'] = _toDouble(processedPayment['amount']);
            processedPayments.add(processedPayment);
          }
        }

        // Use stats from API if available
        Map<String, dynamic> stats = _stats;
        if (statsResult['success']) {
          final apiStats = statsResult['stats'];
          if (apiStats is Map<String, dynamic>) {
            stats = {
              'totalPayments': apiStats['totalPayments'] ?? 0,
              'successfulCount': apiStats['successfulCount'] ?? 0,
              'pendingCount': apiStats['pendingCount'] ?? 0,
              'failedCount': apiStats['failedCount'] ?? 0,
              'totalAmount': _toDouble(apiStats['totalAmount']),
            };
          }
        }

        setState(() {
          _allPayments = processedPayments;
          _stats = stats;
          _isLoading = false;
          _isRefreshing = false;
        });

        print('✅ Loaded ${processedPayments.length} payments');
      } else {
        _showError('Unable to load payments. Please try again.');
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      print('❌ Error loading payments: $e');
      _showError('Network error. Please check your connection.');
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadActiveLoans() async {
    try {
      final loansResult = await _apiService.getUserLoans(
        status: 'active',
        limit: 100,
      );

      if (loansResult['success']) {
        final loans = loansResult['loans'] as List? ?? [];

        // Process loans with safe type conversion
        final List<Map<String, dynamic>> processedLoans = [];
        for (var loan in loans) {
          if (loan is Map<String, dynamic>) {
            final processedLoan = Map<String, dynamic>.from(loan);

            final amount = _toDouble(processedLoan['amount']);
            final paidAmount = _toDouble(processedLoan['paidAmount']);
            final term = processedLoan['term'] is int
                ? processedLoan['term'] as int
                : (processedLoan['term'] as double?)?.toInt() ?? 1;

            final installmentAmount = amount / term;
            final remainingAmount = amount - paidAmount;

            processedLoan['nextInstallment'] = remainingAmount < installmentAmount
                ? remainingAmount
                : installmentAmount;
            processedLoan['remainingAmount'] = remainingAmount;
            processedLoan['installmentAmount'] = installmentAmount;

            processedLoans.add(processedLoan);
          }
        }

        setState(() {
          _activeLoans = processedLoans;
        });

        print('✅ Loaded ${processedLoans.length} active loans');
      }
    } catch (e) {
      print('❌ Error loading active loans: $e');
    }
  }

  Future<void> _refreshPayments() async {
    setState(() => _isRefreshing = true);
    await Future.wait([
      _loadPayments(),
      _loadActiveLoans(),
    ]);
  }

  String _mapPaymentStatus(String? apiStatus) {
    if (apiStatus == null) return 'unknown';
    final status = apiStatus.toLowerCase();

    if (status.contains('success') || status.contains('completed') || status == 'success') {
      return 'success';
    } else if (status.contains('pending') || status.contains('processing')) {
      return 'pending';
    } else if (status.contains('fail') || status.contains('error') || status.contains('rejected')) {
      return 'failed';
    }
    return status;
  }

  void _showError(String message, {BuildContext? overlayContext}) {
    if (!mounted) return;
    final contextToUse = overlayContext ?? context;

    ScaffoldMessenger.of(contextToUse).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showSuccess(String message, {BuildContext? overlayContext}) {
    if (!mounted) return;
    final contextToUse = overlayContext ?? context;

    ScaffoldMessenger.of(contextToUse).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showInfo(String message, {BuildContext? overlayContext}) {
    if (!mounted) return;
    final contextToUse = overlayContext ?? context;

    ScaffoldMessenger.of(contextToUse).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  double get _totalPaid => _toDouble(_stats['totalAmount']);

  List<Map<String, dynamic>> get _filteredPayments {
    if (_allPayments.isEmpty) return [];

    return _allPayments.where((payment) {
      final displayStatus = payment['displayStatus'] ?? _mapPaymentStatus(payment['status']);

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return (payment['loanId_display']?.toString().toLowerCase() ?? '').contains(query) ||
            (payment['loanId']?.toString().toLowerCase() ?? '').contains(query) ||
            (payment['invoiceId']?.toString().toLowerCase() ?? '').contains(query) ||
            (payment['transactionId']?.toString().toLowerCase() ?? '').contains(query);
      }

      if (_selectedFilter != 'All') {
        return displayStatus == _selectedFilter.toLowerCase();
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveLoans = _activeLoans.isNotEmpty;
    final hasPayments = _allPayments.isNotEmpty;

    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshPayments,
            color: AppColors.primaryGreen,
            child: _isLoading
                ? _buildLoadingShimmer()
                : CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),

                if (hasPayments)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(child: _buildStatsCard()),
                  ),

                if (!hasPayments && !_isLoading)
                  SliverToBoxAdapter(child: _buildWelcomeMessage()),

                if (hasPayments)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(child: _buildSearchAndFilter()),
                  ),

                // Payment List
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: _filteredPayments.isEmpty && hasPayments
                      ? SliverToBoxAdapter(child: _buildEmptyState())
                      : SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final payment = _filteredPayments[index];
                        final displayStatus = payment['displayStatus'] ??
                            _mapPaymentStatus(payment['status']);

                        // Safely parse date
                        DateTime? paymentDate;
                        if (payment['createdAt'] != null) {
                          paymentDate = _parseDate(payment['createdAt']);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PaymentCard(
                            loanId: payment['loanId_display']?.toString() ??
                                payment['loanId']?.toString() ?? 'N/A',
                            amount: _toDouble(payment['amount']),
                            method: payment['paymentMethod']?.toString() ?? 'Unknown',
                            date: paymentDate != null
                                ? _dateFormat.format(paymentDate)
                                : 'N/A',
                            status: displayStatus,
                            onTap: () => _showPaymentDetails(payment),
                          ),
                        );
                      },
                      childCount: _filteredPayments.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ),
        floatingActionButton: hasActiveLoans
            ? FloatingActionButton.extended(
          onPressed: _showMakePaymentSheet,
          backgroundColor: AppColors.primaryGreen,
          icon: const Icon(Icons.payment, color: Colors.white),
          label: const Text(
            "Pay Now",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Payments",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            "Manage your loan payments",
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Paid",
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatAmount(_totalPaid),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem("Payments", _stats['totalPayments'].toString()),
              _buildStatItem("Successful", _stats['successfulCount'].toString()),
              _buildStatItem("Pending", _stats['pendingCount'].toString()),
              _buildStatItem("Failed", _stats['failedCount'].toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: "Search by Loan ID or Reference",
              hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => setState(() => _searchQuery = ''),
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.background,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', Icons.all_inclusive),
                const SizedBox(width: 8),
                _buildFilterChip('success', Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                _buildFilterChip('pending', Icons.pending, color: Colors.orange),
                const SizedBox(width: 8),
                _buildFilterChip('failed', Icons.error, color: Colors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, {Color? color}) {
    final isSelected = _selectedFilter == label;
    final chipColor = color ?? AppColors.primaryGreen;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : chipColor),
      onSelected: (selected) => setState(() => _selectedFilter = selected ? label : 'All'),
      backgroundColor: Colors.white,
      selectedColor: chipColor,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payment_outlined, size: 50, color: AppColors.primaryGreen),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Payments Yet",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            "When you make payments on your active loans, they will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_activeLoans.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "You have ${_activeLoans.length} active loan${_activeLoans.length > 1 ? 's' : ''}. Tap the Pay Now button to make a payment.",
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView(
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(height: 150, decoration: _shimmerDecoration()),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(height: 100, decoration: _shimmerDecoration()),
        ),
        ...List.generate(3, (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(height: 80, decoration: _shimmerDecoration()),
        )),
      ],
    );
  }

  BoxDecoration _shimmerDecoration() {
    return BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(16),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No matching payments',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'No payments match "$_searchQuery"'
                : 'No $_selectedFilter payments found',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    final displayStatus = payment['displayStatus'] ?? _mapPaymentStatus(payment['status']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 50, height: 4, decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                )),
              ),
              const SizedBox(height: 24),
              const Text("Payment Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _buildDetailRow("Transaction ID", payment['transactionId']?.toString() ?? 'N/A'),
              _buildDetailRow("Invoice ID", payment['invoiceId']?.toString() ?? 'N/A'),
              _buildDetailRow("Loan ID", payment['loanId_display']?.toString() ?? payment['loanId']?.toString() ?? 'N/A'),
              _buildDetailRow("Amount", _formatAmount(payment['amount'])),
              _buildDetailRow("Method", payment['paymentMethod']?.toString() ?? 'N/A'),
              _buildDetailRow("Phone", payment['phoneNumber']?.toString() ?? 'N/A'),
              _buildDetailRow(
                "Date",
                payment['createdAt'] != null ? _dateFormat.format(DateTime.parse(payment['createdAt'])) : 'N/A',
              ),
              if (payment['referenceId'] != null)
                _buildDetailRow("Reference", payment['referenceId'].toString()),
              _buildDetailRow("Status", displayStatus.toUpperCase()),
              if (payment['waafiResponse'] != null && payment['waafiResponse']['responseMsg'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      'Response: ${payment['waafiResponse']['responseMsg']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        final loanId = payment['loanId']?.toString();
                        if (loanId != null && loanId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => LoanDetailsScreen(loanId: loanId)),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('View Loan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  void _showMakePaymentSheet() {
    if (_activeLoans.isEmpty) {
      _showInfo('No active loans available for payment');
      return;
    }

    _amountController.clear();
    _phoneController.clear();
    _selectedPaymentMethod = 'EVC Plus';
    _selectedLoan = null;
    _selectedLoanId = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 50, height: 4, decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    )),
                  ),
                  const SizedBox(height: 24),
                  const Text("Make a Payment", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Select a loan to make payment", style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 20),

                  // Loan Selection
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedLoanId,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: const Text('Select Loan'),
                      items: _activeLoans.map((loan) {
                        final nextInstallment = _toDouble(loan['nextInstallment'] ?? loan['installmentAmount'] ?? 0);
                        final remainingAmount = _toDouble(loan['remainingAmount'] ?? loan['amount']);

                        return DropdownMenuItem<String>(
                          value: loan['_id'] as String?,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${loan['loanId']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                'Next: ${_formatAmount(nextInstallment)} | Remaining: ${_formatAmount(remainingAmount)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setSheetState(() {
                          _selectedLoanId = value;
                          _selectedLoan = _activeLoans.firstWhere((loan) => loan['_id'] == value, orElse: () => {});

                          if (_selectedLoan != null && _selectedLoan!.isNotEmpty) {
                            final nextAmount = _toDouble(_selectedLoan!['nextInstallment'] ??
                                _selectedLoan!['installmentAmount'] ?? 0);
                            if (nextAmount > 0) {
                              _amountController.text = nextAmount.toStringAsFixed(2);
                            }
                          }
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Amount Field
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Installment Amount',
                      hintText: 'Auto-filled from loan',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Phone Number Field
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Your EVC Plus Number',
                      hintText: '2526XXXXXXX',
                      helperText: 'Enter your EVC Plus mobile money number',
                      prefixIcon: const Icon(Icons.phone_android),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment Method Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'EVC Plus is currently the only available payment method. Make sure you have sufficient balance.',
                            style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_isProcessingPayment) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                            strokeWidth: 2,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Waiting for payment confirmation... $_secondsLeft seconds left",
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isProcessingPayment ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessingPayment ? null : () async {
                            if (_validatePayment()) {
                              Navigator.pop(context);
                              await _processPayment();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isProcessingPayment
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Text('Process Payment'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _validatePayment() {
    if (_selectedLoanId == null) {
      _showError('Please select a loan to continue');
      return false;
    }

    if (_amountController.text.isEmpty) {
      _showError('Payment amount is required');
      return false;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      _showError('Please enter a valid payment amount');
      return false;
    }

    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Please enter your EVC Plus phone number');
      return false;
    }

    // Validate EVC Plus number format
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (!cleanPhone.startsWith('2526')) {
      _showError('EVC Plus number must start with 2526');
      return false;
    }

    if (cleanPhone.length < 12) {
      _showError('Please enter a complete EVC Plus number (12 digits including 252)');
      return false;
    }

    return true;
  }

  void _startCountdown() {
    _secondsLeft = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        if (mounted) {
          setState(() => _isProcessingPayment = false);
          _showError('⏱️ Payment timeout. Please try again.');
        }
      }
    });
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessingPayment = true);
    _startCountdown();

    try {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final phone = _phoneController.text.trim();
      final invoiceId = 'LN-${DateTime.now().millisecondsSinceEpoch}';

      if (!mounted) return;

      // Show waiting dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                ),
                const SizedBox(height: 20),
                const Text(
                  "📲 Processing Payment",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Please check your EVC Plus phone and enter your PIN to confirm",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "⏳ $_secondsLeft seconds left",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );

      // Process payment
      final result = await _apiService.processLoanPayment(
        loanId: _selectedLoanId!,
        amount: amount,
        paymentMethod: _selectedPaymentMethod,
        phoneNumber: phone,
        invoiceId: invoiceId,
      );

      // Close dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _countdownTimer?.cancel();

      if (result['success']) {
        final successMsg = _getSuccessMessage(result['data']);
        _showSuccess(successMsg);
        await _refreshPayments();
      } else {
        final errorMsg = result['message'] ?? 'Payment failed';
        final responseMsg = result['data']?['waafiResponse']?['responseMsg'];
        final userFriendlyMsg = _getUserFriendlyErrorMessage(errorMsg, responseMsg);
        _showError(userFriendlyMsg);
      }

    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _countdownTimer?.cancel();

      final errorMsg = e.toString();
      if (errorMsg.contains('timeout')) {
        _showError('⏱️ Connection timeout. Please check your internet and try again.');
      } else {
        _showError(_getUserFriendlyErrorMessage(errorMsg, null));
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }
}