// guarantor_screens/guarantor_loan_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../utils/app_constants.dart';

class GuarantorLoanDetailsScreen extends StatefulWidget {
  final String loanId;

  const GuarantorLoanDetailsScreen({super.key, required this.loanId});

  @override
  State<GuarantorLoanDetailsScreen> createState() => _GuarantorLoanDetailsScreenState();
}

class _GuarantorLoanDetailsScreenState extends State<GuarantorLoanDetailsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRefreshing = false;
  int _currentTabIndex = 0;

  late TabController _tabController;

  // Data from API
  Map<String, dynamic> _loan = {};
  List<dynamic> _schedule = [];
  List<dynamic> _payments = [];
  Map<String, dynamic> _risk = {};

  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$');
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final DateFormat _timeFormat = DateFormat('hh:mm a');

  // Helper method to safely convert to double
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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });

      // Lazy load data when tabs are switched
      if (_currentTabIndex == 1 && _schedule.isEmpty) {
        _loadSchedule();
      } else if (_currentTabIndex == 2 && _payments.isEmpty) {
        _loadPayments();
      }
    });

    _loadLoanDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLoanDetails() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }

    try {
      // Load main loan details
      final result = await _apiService.getGuarantorLoanDetails(widget.loanId);

      if (mounted) {
        if (result['success']) {
          setState(() {
            _loan = result['data'] ?? {};
            _risk = _loan['risk'] ?? {};
            _isLoading = false;
            _isRefreshing = false;
          });
        } else {
          _showErrorSnackBar(result['message'] ?? 'Failed to load loan details');
          setState(() {
            _isLoading = false;
            _isRefreshing = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading loan details: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load loan details. Please try again.');
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadSchedule() async {
    try {
      final result = await _apiService.getGuarantorLoanSchedule(widget.loanId);

      if (mounted && result['success']) {
        setState(() {
          _schedule = result['data']['schedule'] ?? [];
        });
      }
    } catch (e) {
      print('❌ Error loading schedule: $e');
    }
  }

  Future<void> _loadPayments() async {
    try {
      final result = await _apiService.getGuarantorLoanPayments(widget.loanId);

      if (mounted && result['success']) {
        setState(() {
          _payments = result['data']['payments'] ?? [];
        });
      }
    } catch (e) {
      print('❌ Error loading payments: $e');
    }
  }

  Future<void> _refreshLoanDetails() async {
    setState(() => _isRefreshing = true);

    // Reset data
    setState(() {
      _schedule = [];
      _payments = [];
    });

    await _loadLoanDetails();

    // Reload current tab data if needed
    if (_currentTabIndex == 1) {
      await _loadSchedule();
    } else if (_currentTabIndex == 2) {
      await _loadPayments();
    }
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

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return AppColors.primaryGreen;
      case 'overdue':
        return Colors.red;
      case 'completed':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getRiskColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'critical':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'UN';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final status = _loan['status']?.toString().toLowerCase() ?? 'unknown';
    final statusColor = _getStatusColor(status);
    final borrower = _loan['borrower'] ?? {};
    final progress = _toDouble(_loan['progress']);
    final nextPayment = _loan['nextPayment'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading && !_isRefreshing
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refreshLoanDetails,
        color: AppColors.primaryGreen,
        child: CustomScrollView(
          slivers: [
            // App Bar with Gradient
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: statusColor,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 70, bottom: 16),
                title: Text(
                  _loan['loanId'] ?? 'Loan Details',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        statusColor,
                        statusColor.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Loan Amount',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currencyFormat.format(_toDouble(_loan['amount'])),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      status == 'overdue'
                                          ? Icons.warning
                                          : Icons.check_circle,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primaryGreen,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primaryGreen,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home, size: 16),
                            SizedBox(width: 4),
                            Text('Overview'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.schedule, size: 16),
                            SizedBox(width: 4),
                            Text('Schedule'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, size: 16),
                            SizedBox(width: 4),
                            Text('Payments'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tab Bar View
            SliverFillRemaining(
              child: Container(
                color: Colors.white,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(borrower, statusColor, progress, nextPayment),
                    _buildScheduleTab(),
                    _buildPaymentsTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> borrower, Color statusColor, double progress, Map<String, dynamic>? nextPayment) {
    // Get the loan status from _loan, not from parameters
    final loanStatus = _loan['status']?.toString().toLowerCase() ?? 'unknown';

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // Borrower Info Card
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
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _getInitials(borrower['name']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      borrower['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      borrower['email'] ?? 'No email',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      borrower['phone'] ?? 'No phone',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.contact_support,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Stats Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.8,
          children: [
            _buildStatCard(
              'Paid Amount',
              _currencyFormat.format(_toDouble(_loan['paidAmount'])),
              Icons.payment,
              Colors.green,
            ),
            _buildStatCard(
              'Remaining',
              _currencyFormat.format(_toDouble(_loan['remainingAmount'])),
              Icons.trending_up,
              Colors.orange,
            ),
            _buildStatCard(
              'Interest Rate',
              '${_loan['interestRate'] ?? 0}%',
              Icons.percent,
              Colors.purple,
            ),
            _buildStatCard(
              'Term',
              '${_loan['term'] ?? 0} months',
              Icons.calendar_month,
              Colors.blue,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Payment Progress Chart
        if ((_toDouble(_loan['paidAmount']) > 0) || (_toDouble(_loan['remainingAmount']) > 0))
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 100,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                value: _toDouble(_loan['paidAmount']),
                                title: '${(progress * 100).toInt()}%',
                                color: Colors.green,
                                radius: 40,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              PieChartSectionData(
                                value: _toDouble(_loan['remainingAmount']),
                                title: '${(100 - progress * 100).toInt()}%',
                                color: Colors.orange.shade300,
                                radius: 40,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                            centerSpaceRadius: 30,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem(
                            'Paid',
                            Colors.green,
                            _currencyFormat.format(_toDouble(_loan['paidAmount'])),
                          ),
                          const SizedBox(height: 8),
                          _buildLegendItem(
                            'Remaining',
                            Colors.orange.shade300,
                            _currencyFormat.format(_toDouble(_loan['remainingAmount'])),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Loan Details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Loan Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Start Date', _loan['startDate'] != null
                  ? _dateFormat.format(DateTime.parse(_loan['startDate']))
                  : 'N/A'),
              _buildDetailRow('End Date', _loan['endDate'] != null
                  ? _dateFormat.format(DateTime.parse(_loan['endDate']))
                  : 'N/A'),
              _buildDetailRow('Purpose', _loan['purpose'] ?? 'N/A'),
              _buildDetailRow('Description', _loan['description'] ?? 'N/A'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Risk Assessment
        if (_risk.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: loanStatus == 'overdue' ? Colors.red : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assessment,
                      color: loanStatus == 'overdue' ? Colors.red : AppColors.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Risk Assessment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getRiskColor(_risk['level']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _risk['level'] == 'low'
                            ? Icons.check_circle
                            : _risk['level'] == 'medium'
                            ? Icons.warning
                            : Icons.error,
                        color: _getRiskColor(_risk['level']),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_risk['level']?.toString().toUpperCase() ?? 'UNKNOWN'} RISK',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getRiskColor(_risk['level']),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Score: ${_risk['score'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_risk['factors'] != null && _risk['factors'].isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...(_risk['factors'] as List).map((factor) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              factor.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    if (_schedule.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No schedule available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _schedule.length,
      itemBuilder: (context, index) {
        final installment = _schedule[index];
        final isPaid = installment['status'] == 'paid';
        final dueDate = _parseDate(installment['dueDate']);
        final isOverdue = !isPaid && dueDate != null && dueDate.isBefore(DateTime.now());

        if (dueDate == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPaid
                ? Colors.green.withOpacity(0.05)
                : isOverdue
                ? Colors.red.withOpacity(0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPaid
                      ? Colors.green
                      : isOverdue
                      ? Colors.red
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${installment['installmentNo'] ?? index + 1}',
                    style: TextStyle(
                      color: isPaid || isOverdue ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateFormat.format(dueDate),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPaid
                          ? 'Paid'
                          : isOverdue
                          ? 'Overdue'
                          : 'Pending',
                      style: TextStyle(
                        fontSize: 12,
                        color: isPaid
                            ? Colors.green
                            : isOverdue
                            ? Colors.red
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(_toDouble(installment['amount'])),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPaid
                          ? Colors.green
                          : isOverdue
                          ? Colors.red
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'P: ${_currencyFormat.format(_toDouble(installment['principal']))}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No payments recorded yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        final paymentDate = _parseDate(payment['date']);

        if (paymentDate == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 5,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.payment,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currencyFormat.format(_toDouble(payment['amount'])),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_dateFormat.format(paymentDate)} • ${_timeFormat.format(paymentDate)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (payment['method'] != null) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          payment['method'],
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color, String amount) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        )),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(amount, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}