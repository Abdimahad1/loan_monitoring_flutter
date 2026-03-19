// guarantor_screens/guarantor_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../auth_screens/login_sign_up_screens.dart';
import '../borrower_screens/change_password_screen.dart';
import '../borrower_screens/edit_profile_screen.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/app_constants.dart';
import '../widgets/profile_menu_item.dart';
import 'guarantor_statistics_screen.dart';

class GuarantorProfileScreen extends StatefulWidget {
  const GuarantorProfileScreen({super.key});

  @override
  State<GuarantorProfileScreen> createState() => _GuarantorProfileScreenState();
}

class _GuarantorProfileScreenState extends State<GuarantorProfileScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRefreshing = false;

  UserModel? _user;
  Map<String, dynamic> _guarantorStats = {
    'totalGuaranteed': 0,
    'activeLoans': 0,
    'overdueLoans': 0,
    'completedLoans': 0,
    'totalAmount': 0.0,
    'atRiskAmount': 0.0,
    'paidAmount': 0.0,
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

    _loadGuarantorData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadGuarantorData() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }

    try {
      print('📱 Loading guarantor profile data...');

      // Get stored user first
      final storedUser = await _apiService.getStoredUser();

      // Get fresh user data from API
      final userResult = await _apiService.getCurrentUser();

      UserModel? freshUser;
      if (userResult['success']) {
        freshUser = userResult['user'];
      }

      // Get guarantor stats
      final statsResult = await _apiService.getGuarantorStats();

      // Get guaranteed loans for recent activity
      final loansResult = await _apiService.getGuarantorLoans(limit: 10);

      if (statsResult['success']) {
        setState(() {
          _guarantorStats = statsResult['data'] ?? _guarantorStats;
        });
      }

      // Process recent activity from guaranteed loans
      final List<Map<String, dynamic>> activity = [];

      if (loansResult['success']) {
        final loans = loansResult['data'] ?? [];

        for (var loan in loans) {
          final status = loan['status']?.toString().toLowerCase() ?? '';
          final borrower = loan['borrower'] ?? {};

          // Add loan status changes
          if (status == 'active') {
            activity.add({
              'type': 'loan_approved',
              'title': 'Loan Approved',
              'subtitle': '${borrower['name'] ?? 'Borrower'} - ${loan['loanId']}',
              'amount': _toDouble(loan['amount']),
              'date': _parseDate(loan['approvedAt'] ?? loan['startDate']),
              'status': 'approved',
            });
          } else if (status == 'overdue') {
            activity.add({
              'type': 'overdue',
              'title': 'Overdue Alert',
              'subtitle': '${borrower['name'] ?? 'Borrower'} - ${loan['loanId']}',
              'amount': _toDouble(loan['amount']),
              'date': DateTime.now(),
              'status': 'warning',
            });
          } else if (status == 'completed') {
            activity.add({
              'type': 'completed',
              'title': 'Loan Completed',
              'subtitle': '${borrower['name'] ?? 'Borrower'} - ${loan['loanId']}',
              'amount': _toDouble(loan['amount']),
              'date': _parseDate(loan['endDate']),
              'status': 'success',
            });
          }
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
        _recentActivity = activity.take(5).toList();
      });

    } catch (e) {
      print('❌ Error loading guarantor profile: $e');
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
    await _loadGuarantorData();
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
    if (name == null || name.isEmpty) return 'G';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final atRisk = _guarantorStats['atRiskAmount'] > 0;
    final totalAmount = _toDouble(_guarantorStats['totalAmount']);
    final paidAmount = _toDouble(_guarantorStats['paidAmount']);
    final atRiskAmount = _toDouble(_guarantorStats['atRiskAmount']);

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

              // Guarantor Stats Cards
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
                          title: "Guarantor Statistics",
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GuarantorStatisticsScreen(
                                  stats: _guarantorStats,
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
                    _getInitials(_user?.name),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ),
              if (_guarantorStats['overdueLoans'] > 0)
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
                      _guarantorStats['overdueLoans'].toString(),
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
            _user?.name ?? 'Guarantor',
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
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'GUARANTOR',
              style: TextStyle(
                color: Colors.blue,
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
    final totalGuaranteed = _guarantorStats['totalGuaranteed'] ?? 0;
    final activeLoans = _guarantorStats['activeLoans'] ?? 0;
    final overdueLoans = _guarantorStats['overdueLoans'] ?? 0;
    final completedLoans = _guarantorStats['completedLoans'] ?? 0;
    final totalAmount = _toDouble(_guarantorStats['totalAmount']);
    final atRiskAmount = _toDouble(_guarantorStats['atRiskAmount']);

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
                "Guarantor Summary",
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
                    Icons.shield,
                    "Guaranteeing",
                    totalGuaranteed.toString(),
                    Colors.blue,
                  ),
                  _buildStatItem(
                    Icons.attach_money,
                    "Total",
                    _formatAmount(totalAmount),
                    AppColors.primaryGreen,
                  ),
                  _buildStatItem(
                    Icons.warning,
                    "At Risk",
                    _formatAmount(atRiskAmount),
                    Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (totalAmount > 0)
                LinearProgressIndicator(
                  value: atRiskAmount / totalAmount,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    atRiskAmount / totalAmount > 0.3 ? Colors.red : Colors.orange,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              const SizedBox(height: 8),
              Text(
                '${totalAmount > 0 ? (atRiskAmount / totalAmount * 100).toStringAsFixed(1) : 0}% at risk',
                style: TextStyle(
                  fontSize: 12,
                  color: atRiskAmount > 0 ? Colors.red : AppColors.textSecondary,
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
                activeLoans.toString(),
                Icons.trending_up,
                AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                'Completed',
                completedLoans.toString(),
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
                'Overdue',
                overdueLoans.toString(),
                Icons.warning,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                'Total',
                totalGuaranteed.toString(),
                Icons.shield,
                Colors.blue,
              ),
            ),
          ],
        ),

        if (overdueLoans > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attention Needed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        'You have $overdueLoans overdue loan${overdueLoans > 1 ? 's' : ''} totaling ${_formatAmount(atRiskAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
    Color color;
    IconData icon;

    switch (activity['type']) {
      case 'loan_approved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'overdue':
        color = Colors.red;
        icon = Icons.warning;
        break;
      case 'completed':
        color = Colors.blue;
        icon = Icons.done_all;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }

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
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
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