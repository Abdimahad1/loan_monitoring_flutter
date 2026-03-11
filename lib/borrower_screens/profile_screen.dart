import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth_screens/login_sign_up_screens.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/app_constants.dart';
import '../widgets/profile_menu_item.dart';
import 'change_password_screen.dart';
import 'loan_statistics_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRefreshing = false;

  UserModel? _user;
  Map<String, dynamic> _loanStats = {
    'totalLoans': 0,
    'activeLoans': 0,
    'completedLoans': 0,
    'pendingLoans': 0,
    'overdueLoans': 0,
    'totalBorrowed': 0.0,
    'totalRepaid': 0.0,
    'totalRemaining': 0.0,
    'totalInterest': 0.0,
    'onTimePayments': 0,
    'latePayments': 0,
    'paymentRate': 0.0,
  };

  List<Map<String, dynamic>> _recentActivity = [];

  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$');
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }

    try {
      print('📱 Loading profile data...');

      // Get stored user first for immediate display
      final storedUser = await _apiService.getStoredUser();

      // Get fresh user data from API
      final userResult = await _apiService.getCurrentUser();

      UserModel? freshUser;
      if (userResult['success']) {
        freshUser = userResult['user'];
        print('✅ Fresh user data loaded: ${freshUser?.name}');
      }

      // Get all loans for statistics
      final loansResult = await _apiService.getUserLoans(limit: 100);

      // Get payment history for accurate paid amount calculation
      final paymentsResult = await _apiService.getUserPaymentHistory(limit: 100);

      if (loansResult['success']) {
        final loans = loansResult['loans'] as List;

        // First, calculate total paid amount from successful payments
        double totalPaidFromPayments = 0.0;
        final Map<String, List<dynamic>> paymentsByLoan = {};

        if (paymentsResult['success']) {
          final payments = paymentsResult['payments'] as List? ?? [];
          for (var payment in payments) {
            if (payment is Map<String, dynamic>) {
              if (payment['status']?.toString().toLowerCase() == 'success') {
                final amount = _toDouble(payment['amount']);
                totalPaidFromPayments += amount;

                // Group payments by loan ID for later use
                final loanId = payment['loanId']?.toString() ??
                    payment['loanId_display']?.toString();
                if (loanId != null) {
                  if (!paymentsByLoan.containsKey(loanId)) {
                    paymentsByLoan[loanId] = [];
                  }
                  paymentsByLoan[loanId]!.add(payment);
                }
              }
            }
          }
        }

        int activeCount = 0;
        int completedCount = 0;
        int pendingCount = 0;
        int overdueCount = 0;
        double totalBorrowed = 0.0;
        double totalRepaid = 0.0;
        double totalInterest = 0.0;
        int onTimePayments = 0;
        int latePayments = 0;

        for (var loan in loans) {
          final amount = _toDouble(loan['amount']);
          final paid = _toDouble(loan['paidAmount']);
          final interest = _toDouble(loan['interestRate']);

          totalBorrowed += amount;
          totalInterest += (amount * interest / 100);

          // Use paid amount from payments if available, otherwise use loan's paidAmount
          final loanId = loan['_id']?.toString();
          double loanPaidAmount = 0.0;

          if (loanId != null && paymentsByLoan.containsKey(loanId)) {
            for (var payment in paymentsByLoan[loanId]!) {
              loanPaidAmount += _toDouble(payment['amount']);
            }
          } else {
            loanPaidAmount = paid;
          }

          totalRepaid += loanPaidAmount;

          final status = loan['status']?.toString().toLowerCase() ?? '';
          if (status == 'active') {
            activeCount++;
          } else if (status == 'completed') {
            completedCount++;
          } else if (status == 'pending' || status == 'approved') {
            pendingCount++;
          } else if (status == 'overdue') {
            overdueCount++;
          }

          // Count payments from schedule using the same logic as LoanDetailsScreen
          final schedule = loan['schedule'];
          if (schedule is List) {
            // Calculate installment amount
            final term = schedule.length;
            final installmentAmount = amount / term;

            // Calculate how many installments are paid based on loanPaidAmount
            final paidInstallmentsCount = (loanPaidAmount / installmentAmount).round();

            int paidSoFar = 0;
            for (var inst in schedule) {
              if (inst is Map) {
                if (paidSoFar < paidInstallmentsCount) {
                  // This installment is considered paid
                  paidSoFar++;

                  // Check if paid on time
                  final dueDate = _parseDate(inst['dueDate']);
                  if (dueDate != null) {
                    if (dueDate.isAfter(DateTime.now())) {
                      onTimePayments++;
                    } else {
                      latePayments++;
                    }
                  } else {
                    onTimePayments++;
                  }
                }
              }
            }
          }
        }

        // Process recent activity from payments (only successful ones)
        final List<Map<String, dynamic>> activity = [];
        if (paymentsResult['success']) {
          final payments = paymentsResult['payments'] as List? ?? [];
          for (var payment in payments) {
            if (payment is Map<String, dynamic>) {
              // Only show successful payments in activity
              if (payment['status']?.toString().toLowerCase() == 'success') {
                activity.add({
                  'type': 'payment',
                  'title': 'Payment Made',
                  'subtitle': 'Loan: ${payment['loanId_display'] ?? payment['loanId']}',
                  'amount': _toDouble(payment['amount']),
                  'date': _parseDate(payment['createdAt']),
                  'status': 'success',
                });
              }
            }
          }
        }

        // Add loan applications to activity (only approved/active ones)
        for (var loan in loans) {
          final status = loan['status']?.toString().toLowerCase() ?? '';
          if (status == 'approved' || status == 'active') {
            activity.add({
              'type': 'loan',
              'title': 'Loan Approved',
              'subtitle': 'Loan: ${loan['loanId']}',
              'amount': _toDouble(loan['amount']),
              'date': _parseDate(loan['approvedAt'] ?? loan['createdAt']),
              'status': 'approved',
            });
          }
        }

        // Sort by date (newest first)
        activity.sort((a, b) {
          final dateA = a['date'] as DateTime?;
          final dateB = b['date'] as DateTime?;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

        setState(() {
          _user = freshUser ?? storedUser;
          _loanStats = {
            'totalLoans': loans.length,
            'activeLoans': activeCount,
            'completedLoans': completedCount,
            'pendingLoans': pendingCount,
            'overdueLoans': overdueCount,
            'totalBorrowed': totalBorrowed,
            'totalRepaid': totalRepaid, // This now uses actual payment data
            'totalRemaining': totalBorrowed - totalRepaid,
            'totalInterest': totalInterest,
            'onTimePayments': onTimePayments,
            'latePayments': latePayments,
            'paymentRate': totalBorrowed > 0
                ? (totalRepaid / totalBorrowed * 100)
                : 0.0,
          };
          _recentActivity = activity.take(5).toList();
        });

        print('📊 Profile stats loaded:');
        print('  - Total Loans: ${_loanStats['totalLoans']}');
        print('  - Total Borrowed: ${_loanStats['totalBorrowed']}');
        print('  - Total Repaid: ${_loanStats['totalRepaid']} (from actual payments)');
        print('  - Payment Rate: ${_loanStats['paymentRate']}%');
      }
    } catch (e) {
      print('❌ Error loading profile: $e');
      _showError('Failed to load profile data');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }

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

  String _formatAmount(double amount) {
    return _currencyFormat.format(amount);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _refreshProfile() async {
    setState(() => _isRefreshing = true);
    await _loadUserData();
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginSignUpScreen()),
            (route) => false,
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshProfile,
          color: AppColors.primaryGreen,
          child: _isLoading && !_isRefreshing
              ? _buildLoadingShimmer()
              : CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildHeader(),
                ),
              ),

              // Profile Section
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildProfileSection(),
                ),
              ),

              // Stats Cards
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildStatsSection(),
                  ),
                ),
              ),

              // Recent Activity
              if (_recentActivity.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildRecentActivity(),
                    ),
                  ),
                ),

              // Menu Items
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final items = [
                        ProfileMenuItem(
                          icon: Icons.edit,
                          title: "Edit Profile",
                          color: Colors.purple,
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(user: _user!),
                              ),
                            );
                            if (result == true) {
                              _refreshProfile();
                            }
                          },
                        ),
                        ProfileMenuItem(
                          icon: Icons.lock_outline,
                          title: "Change Password",
                          color: AppColors.primaryGreen,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ChangePasswordScreen(),
                              ),
                            ).then((_) => _refreshProfile());
                          },
                        ),
                        ProfileMenuItem(
                          icon: Icons.bar_chart_outlined,
                          title: "Loan Statistics",
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LoanStatisticsScreen(
                                  stats: _loanStats,
                                ),
                              ),
                            );
                          },
                        ),
                        ProfileMenuItem(
                          icon: Icons.logout,
                          title: "Logout",
                          color: Colors.red,
                          onTap: _showLogoutDialog,
                        ),
                      ];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: items[index],
                      );
                    },
                    childCount: 4,
                  ),
                ),
              ),

              // Version Info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Center(
                    child: Text(
                      "Version 1.0.0",
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            "Profile",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProfile,
            color: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
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
          // Avatar with initials
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryGreen,
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                  child: Text(
                    _user?.initials ?? 'U',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ),
              if (_loanStats['overdueLoans'] > 0)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _loanStats['overdueLoans'].toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Name & Role
          Text(
            _user?.name ?? 'User',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _user?.roleColor.withOpacity(0.1) ?? AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _user?.roleDisplay.toUpperCase() ?? 'BORROWER',
              style: TextStyle(
                color: _user?.roleColor ?? AppColors.primaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Contact Info
          _buildInfoRow(Icons.email_outlined, _user?.email ?? 'No email'),
          _buildInfoRow(Icons.phone_outlined, _user?.phone ?? 'No phone'),
          if (_user?.idNumber != null && _user!.idNumber!.isNotEmpty)
            _buildInfoRow(Icons.badge_outlined, 'ID: ${_user!.idNumber}'),
          if (_user?.address != null && _user!.address!.isNotEmpty)
            _buildInfoRow(Icons.location_on_outlined, _user!.address!),

          const SizedBox(height: 12),

          // Member Since
          if (_user?.createdAt != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Member since ${_dateFormat.format(_user!.createdAt!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      children: [
        // Main Stats Card
        Container(
          padding: const EdgeInsets.all(20),
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
              const Text(
                "Financial Summary",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.trending_up,
                    "Borrowed",
                    _formatAmount(_loanStats['totalBorrowed']),
                    AppColors.primaryGreen,
                  ),
                  _buildStatItem(
                    Icons.payment,
                    "Repaid",
                    _formatAmount(_loanStats['totalRepaid']),
                    Colors.green,
                  ),
                  _buildStatItem(
                    Icons.account_balance,
                    "Remaining",
                    _formatAmount(_loanStats['totalRemaining']),
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _loanStats['paymentRate'] / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '${_loanStats['paymentRate'].toStringAsFixed(1)}% Repaid',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Loan Status Cards
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                'Active',
                _loanStats['activeLoans'].toString(),
                Icons.trending_up,
                AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                'Completed',
                _loanStats['completedLoans'].toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                'Pending',
                _loanStats['pendingLoans'].toString(),
                Icons.pending,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                'Overdue',
                _loanStats['overdueLoans'].toString(),
                Icons.warning,
                Colors.red,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Payment Performance
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildPerformanceItem(
                  'On Time',
                  _loanStats['onTimePayments'].toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              Container(
                height: 30,
                width: 1,
                color: Colors.grey[300],
              ),
              Expanded(
                child: _buildPerformanceItem(
                  'Late',
                  _loanStats['latePayments'].toString(),
                  Icons.warning,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          const Text(
            "Recent Activity",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._recentActivity.map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final date = activity['date'] as DateTime?;
    final isPayment = activity['type'] == 'payment';
    final isSuccess = activity['status']?.toString().toLowerCase() == 'success' ||
        activity['status']?.toString().toLowerCase() == 'completed';

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
              color: isPayment
                  ? (isSuccess ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1))
                  : Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPayment ? Icons.payment : Icons.credit_card,
              color: isPayment
                  ? (isSuccess ? Colors.green : Colors.orange)
                  : Colors.blue,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity['subtitle'],
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
              if (activity['amount'] != null && activity['amount'] > 0)
                Text(
                  _formatAmount(activity['amount']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              if (date != null)
                Text(
                  _dateFormat.format(date),
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.all(16),
          height: 300,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }
}