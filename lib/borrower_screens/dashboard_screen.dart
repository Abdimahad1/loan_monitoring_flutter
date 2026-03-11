import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_service.dart';
import '../utils/app_constants.dart';
import '../widgets/loan_card.dart';
import '../widgets/stat_card.dart';
import '../models/user_model.dart';
import 'loan_details_screen.dart';
import 'my_loans_screen.dart';
import 'payments_screen.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRefreshing = false;
  UserModel? _currentUser;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic> _dashboardData = {
    'loans': [],
    'stats': {
      'activeLoans': 0,
      'activeAmount': 0.0,
      'paidAmount': 0.0,
      'totalLoans': 0,
      'nextPayment': null,
      'nextPaymentAmount': 0.0,
      'daysToNextPayment': 0,
      'overdueCount': 0,
      'overdueAmount': 0.0,
      'paidInstallments': 0,
      'totalInstallments': 0
    },
    'chartData': [],
    'notifications': 0,
    'recentPayments': []
  };

  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );

  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final ScrollController _scrollController = ScrollController();

  // Helper method to safely convert any value to double
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

  // Helper method to safely parse date
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

  @override
  void initState() {
    super.initState();

    // Animation setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    _loadDashboardData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }

    try {
      // Get current user
      final user = await _apiService.getStoredUser();

      // Get user's loans
      final loansResult = await _apiService.getUserLoans(limit: 50);

      // Get payment history for recent payments
      final paymentsResult = await _apiService.getUserPaymentHistory(limit: 5);

      if (loansResult['success']) {
        final loans = loansResult['loans'] as List? ?? [];
        final recentPayments = _processRecentPayments(paymentsResult);

        // Process loans with safe type conversion
        final List<Map<String, dynamic>> processedLoans = [];
        int totalInstallmentsCount = 0;
        int paidInstallmentsCount = 0;

        for (var loan in loans) {
          if (loan is Map<String, dynamic>) {
            final processedLoan = Map<String, dynamic>.from(loan);

            processedLoan['amount'] = _toDouble(processedLoan['amount']);

            double totalPaidForLoan = 0;

            // Calculate paid amount from payments list
            for (var payment in recentPayments) {
              if (payment['loanId'] == processedLoan['loanId'] &&
                  payment['status'] == 'success') {
                totalPaidForLoan += _toDouble(payment['amount']);
              }
            }

            processedLoan['paidAmount'] = totalPaidForLoan;
            processedLoan['remainingAmount'] =
                processedLoan['amount'] - totalPaidForLoan;

            final schedule = processedLoan['schedule'];
            if (schedule is List) {
              final totalInLoan = schedule.length;

              final installmentAmount =
              totalInLoan > 0 ? processedLoan['amount'] / totalInLoan : 0;

              int paidInstallments = 0;

              if (installmentAmount > 0) {
                paidInstallments =
                    (totalPaidForLoan / installmentAmount).floor();
              }

              totalInstallmentsCount += totalInLoan;
              paidInstallmentsCount += paidInstallments;
            }

            processedLoans.add(processedLoan);
          }
        }


        // Calculate comprehensive stats USING recentPayments for paid amount
        final stats = _calculateStats(processedLoans, recentPayments);

        // Add installment counts to stats
        stats['totalInstallments'] = totalInstallmentsCount;
        stats['paidInstallments'] = paidInstallmentsCount;

        // Generate chart data USING recentPayments
        final chartData = _generateChartData(recentPayments);

        if (mounted) {
          setState(() {
            _currentUser = user;
            _dashboardData = {
              'loans': processedLoans,
              'stats': stats,
              'chartData': chartData,
              'notifications': stats['overdueCount'],
              'recentPayments': recentPayments
            };
          });
        }
      } else {
        if (mounted) {
          _showErrorSnackBar('Could not load dashboard data');
        }
      }
    } catch (e) {
      print('❌ Error loading dashboard: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load dashboard. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Map<String, dynamic> _calculateStats(
      List<Map<String, dynamic>> loans,
      List<Map<String, dynamic>> recentPayments  // Added parameter
      ) {
    double activeAmount = 0;
    double paidAmount = 0; // Will be calculated from payments
    int activeCount = 0;
    int totalLoans = loans.length;
    int overdueCount = 0;
    double overdueAmount = 0;

    DateTime? nextPaymentDate;
    double nextPaymentAmount = 0;

    // FIRST: Calculate paidAmount from successful payments
    for (var payment in recentPayments) {
      if (payment['status'] == 'success') {
        paidAmount += _toDouble(payment['amount']);
      }
    }

    for (var loan in loans) {
      final status = loan['status']?.toString() ?? '';
      final amount = _toDouble(loan['amount']);
      final paid = _toDouble(loan['paidAmount']); // This might be 0 in DB
      final remaining = amount - paid;

      if (status == 'active' || status == 'overdue') {
        activeCount++;
        activeAmount += remaining;

        if (status == 'overdue') {
          overdueCount++;
          overdueAmount += remaining;
        }

        // Find next payment from schedule
        final schedule = loan['schedule'];
        if (schedule is List) {
          for (var payment in schedule) {
            if (payment is Map && payment['status'] == 'pending') {
              try {
                final dueDateStr = payment['dueDate'];
                if (dueDateStr != null) {
                  final dueDate = _parseDate(dueDateStr);
                  if (dueDate != null) {
                    final paymentAmount = _toDouble(payment['amount']);

                    if (nextPaymentDate == null || dueDate.isBefore(nextPaymentDate)) {
                      nextPaymentDate = dueDate;
                      nextPaymentAmount = paymentAmount;
                    }
                  }
                }
              } catch (e) {
                continue;
              }
            }
          }
        }
      }
    }

    return {
      'activeLoans': activeCount,
      'activeAmount': activeAmount,
      'paidAmount': paidAmount, // Now using actual payments data
      'totalLoans': totalLoans,
      'nextPayment': nextPaymentDate,
      'nextPaymentAmount': nextPaymentAmount,
      'daysToNextPayment': nextPaymentDate != null
          ? nextPaymentDate.difference(DateTime.now()).inDays
          : 0,
      'overdueCount': overdueCount,
      'overdueAmount': overdueAmount
    };
  }

  List<Map<String, dynamic>> _generateChartData(List<Map<String, dynamic>> recentPayments) {
    final Map<String, double> dailyTotals = {};
    final now = DateTime.now();

    // Initialize last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final key = DateFormat('EEE').format(date);
      dailyTotals[key] = 0;
    }

    // Use recentPayments for chart data
    for (var payment in recentPayments) {
      try {
        final paymentDate = payment['date'] as DateTime?;
        if (paymentDate != null && payment['status'] == 'success') {
          final daysAgo = now.difference(paymentDate).inDays;

          if (daysAgo <= 6 && daysAgo >= 0) {
            final key = DateFormat('EEE').format(paymentDate);
            dailyTotals[key] = (dailyTotals[key] ?? 0) + _toDouble(payment['amount']);
          }
        }
      } catch (e) {
        continue;
      }
    }

    return dailyTotals.entries.map((e) => {
      'day': e.key,
      'amount': e.value,
    }).toList();
  }

  List<Map<String, dynamic>> _processRecentPayments(Map<String, dynamic> paymentsResult) {
    final recentPayments = <Map<String, dynamic>>[];

    if (paymentsResult['success']) {
      final payments = paymentsResult['payments'] as List? ?? [];
      for (var payment in payments) {
        if (payment is Map<String, dynamic>) {
          recentPayments.add({
            'id': payment['_id'],
            'loanId': payment['loanId_display'] ?? payment['loanId'],
            'amount': _toDouble(payment['amount']),
            'date': _parseDate(payment['createdAt']),
            'status': payment['status'],
            'method': payment['paymentMethod']
          });
        }
      }
      // Sort by date (newest first)
      recentPayments.sort((a, b) {
        final dateA = a['date'] as DateTime?;
        final dateB = b['date'] as DateTime?;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
    }

    return recentPayments;
  }

  Future<void> _refreshDashboard() async {
    setState(() => _isRefreshing = true);
    await _loadDashboardData();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _navigateToLoanDetails(String loanId) {
    if (loanId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoanDetailsScreen(loanId: loanId),
        ),
      );
    }
  }

  void _navigateToMyLoans() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyLoansScreen(),
      ),
    );
  }

  void _navigateToPayments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaymentsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _dashboardData['stats'];
    final hasOverdue = stats['overdueCount'] > 0;
    final hasLoans = _dashboardData['loans'].isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          color: AppColors.primaryGreen,
          child: _isLoading
              ? _buildLoadingShimmer()
              : CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Animated Header
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildHeader(),
                ),
              ),

              // Overdue Warning (if any)
              if (hasOverdue)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _buildOverdueWarning(),
                  ),
                ),

              // Summary Cards
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: _buildSummaryCards(),
                ),
              ),

              // Quick Actions
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _buildQuickActions(),
                ),
              ),

              // Chart Section
              if (_dashboardData['chartData'].isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: _buildChart(),
                  ),
                ),

              // Recent Payments (if any)
              if (_dashboardData['recentPayments'].isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildRecentPayments(),
                  ),
                ),

              // Recent Loans Header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    "Your Loans",
                    hasLoans ? "View All" : "",
                    _navigateToMyLoans,
                  ),
                ),
              ),

              // Recent Loans List - FIXED childCount
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: !hasLoans
                    ? SliverToBoxAdapter(
                  child: _buildEmptyState(),
                )
                    : SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final loans = _dashboardData['loans'] as List;

                          if (index >= loans.length) return null;

                          final loan = loans[index];

                      // Calculate progress safely
                      double progress = 0.0;
                      if (loan['paidAmount'] != null &&
                          loan['amount'] != null &&
                          _toDouble(loan['amount']) > 0) {
                        progress = _toDouble(loan['paidAmount']) / _toDouble(loan['amount']);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LoanCard(
                          loanId: loan['loanId'] ?? 'N/A',
                          amount: _toDouble(loan['amount']),
                          status: loan['status'] ?? 'pending',
                          progress: progress,
                          onTap: () => _navigateToLoanDetails(loan['_id']),
                        ),
                      );
                    },
                    childCount: hasLoans
                        ? (_dashboardData['loans'].length > 3 ? 3 : _dashboardData['loans'].length)
                        : 0,
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final stats = _dashboardData['stats'];
    final notificationCount = _dashboardData['notifications'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 5),
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
                    _getGreeting(),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentUser?.name ?? 'User',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryGreen,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                      child: Text(
                        _currentUser?.name.isNotEmpty == true
                            ? _currentUser!.name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        child: Text(
                          notificationCount > 9 ? '9+' : notificationCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat(
                Icons.credit_card,
                "Active",
                stats['activeLoans'].toString(),
                AppColors.primaryGreen,
              ),
              _buildQuickStat(
                Icons.attach_money,
                "Outstanding",
                _currencyFormat.format(stats['activeAmount']),
                Colors.orange,
              ),
              _buildQuickStat(
                Icons.check_circle,
                "Paid",
                _currencyFormat.format(stats['paidAmount']), // Now shows correct $66.66
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildOverdueWarning() {
    final stats = _dashboardData['stats'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stats['overdueCount']} Overdue Loan${stats['overdueCount'] > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total overdue: ${_currencyFormat.format(stats['overdueAmount'])}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _navigateToMyLoans,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final stats = _dashboardData['stats'];
    final nextPayment = stats['nextPayment'];

    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: "Active Loans",
            value: stats['activeLoans'].toString(),
            icon: Icons.credit_card,
            color: AppColors.primaryGreen,
            subtitle: _currencyFormat.format(stats['activeAmount']),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: nextPayment != null ? "Next Payment" : "No Payment",
            value: nextPayment != null
                ? _currencyFormat.format(stats['nextPaymentAmount'])
                : "---",
            icon: Icons.calendar_today,
            color: nextPayment != null && stats['daysToNextPayment'] < 0
                ? Colors.red
                : Colors.orange,
            subtitle: nextPayment != null
                ? stats['daysToNextPayment'] > 0
                ? "Due in ${stats['daysToNextPayment']} days"
                : stats['daysToNextPayment'] == 0
                ? "Due today"
                : "Overdue by ${-stats['daysToNextPayment']} days"
                : "No upcoming",
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              'My Loans',
              Icons.credit_card,
              AppColors.primaryGreen,
              _navigateToMyLoans,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              'Payments',
              Icons.payment,
              Colors.orange,
              _navigateToPayments,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final chartData = _dashboardData['chartData'];

    if (chartData.isEmpty) {
      return Container(
        height: 200,
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 40,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'No payment data this week',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final maxY = chartData.map((e) => e['amount'] as double).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 220,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Weekly Payments",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Last 7 Days",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY * 1.2 : 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        _currencyFormat.format(rod.toY),
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < chartData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              chartData[value.toInt()]['day'],
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(chartData.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: chartData[index]['amount'],
                        color: AppColors.primaryGreen,
                        width: 18,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPayments() {
    final payments = _dashboardData['recentPayments'];

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Payments",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: _navigateToPayments,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                ),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (payments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No recent payments',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...payments.take(3).map((payment) => _buildRecentPaymentTile(payment)),
        ],
      ),
    );
  }

  Widget _buildRecentPaymentTile(Map<String, dynamic> payment) {
    final date = payment['date'] as DateTime?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payment,
              color: AppColors.primaryGreen,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loan: ${payment['loanId']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date != null ? _dateFormat.format(date) : 'Date unknown',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFormat.format(payment['amount']),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: payment['status'] == 'success'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  payment['status'] == 'success' ? 'Success' : 'Pending',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: payment['status'] == 'success' ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (action.isNotEmpty)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
            child: Text(action),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.credit_card_off,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No loans found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your loans will appear here once you have any',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Navigate to apply for loan
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Apply for Loan'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView(
      children: [
        const SizedBox(height: 20),
        _buildHeaderShimmer(),
        const SizedBox(height: 20),
        _buildSummaryCardsShimmer(),
        const SizedBox(height: 20),
        _buildQuickActionsShimmer(),
        const SizedBox(height: 20),
        _buildChartShimmer(),
        const SizedBox(height: 20),
        _buildLoansListShimmer(),
      ],
    );
  }

  Widget _buildHeaderShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 100, height: 14, color: Colors.white),
                      const SizedBox(height: 8),
                      Container(width: 150, height: 24, color: Colors.white),
                    ],
                  ),
                  Container(width: 56, height: 56, decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  )),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(3, (index) => Column(
                  children: [
                    Container(width: 40, height: 40, decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    )),
                    const SizedBox(height: 8),
                    Container(width: 50, height: 16, color: Colors.white),
                    const SizedBox(height: 4),
                    Container(width: 30, height: 12, color: Colors.white),
                  ],
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCardsShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildLoansListShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: List.generate(3, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          )),
        ),
      ),
    );
  }
}