// guarantor_screens/guarantor_loan_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../utils/app_constants.dart';
import '../widgets/payment_tile.dart';
import '../widgets/installment_tile.dart';

class GuarantorLoanDetailsScreen extends StatefulWidget {
  final String loanId;

  const GuarantorLoanDetailsScreen({super.key, required this.loanId});

  @override
  State<GuarantorLoanDetailsScreen> createState() => _GuarantorLoanDetailsScreenState();
}

class _GuarantorLoanDetailsScreenState extends State<GuarantorLoanDetailsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isRefreshing = false;
  Map<String, dynamic> _loan = {};
  List<dynamic> _schedule = [];
  List<dynamic> _payments = [];
  int _currentTabIndex = 0;

  late TabController _tabController;

  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  final DateFormat _timeFormat = DateFormat('hh:mm a');

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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
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
      print('🔄 Loading guarantor loan details for ID: ${widget.loanId}');

      // First get the loan details using guarantor endpoint
      final loanResult = await _apiService.getGuarantorLoanDetails(widget.loanId);

      // Then get payment history using guarantor-specific payment endpoint
      final paymentsResult = await _apiService.getGuarantorLoanPayments(widget.loanId);

      if (mounted) {
        if (loanResult['success'] == true) {
          final loan = loanResult['data'] as Map<String, dynamic>;

          print('📊 Loan data received:');
          print('  - Loan ID: ${loan['loanId']}');
          print('  - Status: ${loan['status']}');
          print('  - Amount: ${loan['amount']}');

          // Calculate paid amount from payments
          double totalPaidAmount = 0;
          List<dynamic> allPayments = [];

          if (paymentsResult['success'] == true) {
            final paymentsData = paymentsResult['data'] ?? {};
            final payments = paymentsData['payments'] ?? [];

            print('💰 Found ${payments.length} payments');

            for (var payment in payments) {
              if (payment is Map<String, dynamic>) {
                print('  💰 Payment: ${payment['amount']} - ${payment['status']}');

                if (payment['status']?.toString().toLowerCase() == 'success') {
                  final amount = _toDouble(payment['amount']);
                  totalPaidAmount += amount;
                  print('    ✅ Adding: $amount (total now: $totalPaidAmount)');
                }

                final processedPayment = _processPaymentObject(payment);
                if (processedPayment != null) {
                  allPayments.add(processedPayment);
                }
              }
            }
          }

          // If no payments found, use the paidAmount from the loan object
          if (totalPaidAmount == 0) {
            totalPaidAmount = _toDouble(loan['paidAmount']);
            print('📊 Using paid amount from loan object: $totalPaidAmount');
          }

          // Process schedule and mark installments as paid based on payments
          final List<dynamic> processedSchedule = [];
          if (loan['schedule'] != null && loan['schedule'] is List) {
            final scheduleList = loan['schedule'] as List;

            final totalAmount = _toDouble(loan['amount']);
            final term = scheduleList.length;
            final installmentAmount = term > 0 ? totalAmount / term : 0;

            // Use round() to match borrower screen
            final paidInstallmentsCount = installmentAmount > 0
                ? (totalPaidAmount / installmentAmount).round()
                : 0;

            print('📊 Installment amount: $installmentAmount');
            print('📊 Total paid amount: $totalPaidAmount');
            print('📊 Paid installments count (calculated): $paidInstallmentsCount');

            // Track which installments are paid
            int paidSoFar = 0;

            for (int i = 0; i < scheduleList.length; i++) {
              final inst = scheduleList[i];
              if (inst is Map) {
                String status;

                if (paidSoFar < paidInstallmentsCount) {
                  status = 'paid';
                  paidSoFar++;
                  print('✅ Installment #${i + 1} marked as PAID');
                } else {
                  status = inst['status']?.toString().toLowerCase() ?? 'pending';
                  print('📅 Installment #${i + 1} marked as $status');
                }

                processedSchedule.add({
                  'installmentNo': i + 1,
                  'dueDate': inst['dueDate'] ?? inst['due_date'] ?? '',
                  'amount': _toDouble(inst['amount']),
                  'principal': _toDouble(inst['principal'] ?? inst['principalAmount'] ?? 0),
                  'interest': _toDouble(inst['interest'] ?? inst['interestAmount'] ?? 0),
                  'status': status,
                });
              }
            }

            print('📅 Total schedule items: ${processedSchedule.length}');
            print('✅ Total paid installments: $paidSoFar');
          }

          // Sort payments by date (newest first)
          allPayments.sort((a, b) {
            final dateA = a['date'] as DateTime?;
            final dateB = b['date'] as DateTime?;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            return dateB.compareTo(dateA);
          });

          // Update the loan object with calculated paid amount
          loan['paidAmount'] = totalPaidAmount;
          loan['remainingAmount'] = _toDouble(loan['amount']) - totalPaidAmount;

          setState(() {
            _loan = loan;
            _schedule = processedSchedule;
            _payments = allPayments;
          });

          print('✅ Successfully loaded guarantor loan details');
          print('💰 Final paid amount: ${_loan['paidAmount']}');
          print('📊 Progress: ${_getProgress()}');
          print('📊 Paid installments in UI: ${_getPaidInstallments()}');
        } else {
          _showErrorSnackBar(loanResult['message'] ?? 'Failed to load loan details');
        }
      }
    } catch (e) {
      print('❌ Error loading loan details: $e');
      if (mounted) {
        _showErrorSnackBar('Error loading loan details: ${e.toString()}');
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

  Map<String, dynamic>? _processPaymentObject(Map payment) {
    try {
      // Extract date from various possible fields
      DateTime? paymentDate;
      if (payment['createdAt'] != null) {
        paymentDate = _parseDate(payment['createdAt']);
      } else if (payment['date'] != null) {
        paymentDate = _parseDate(payment['date']);
      } else if (payment['processedAt'] != null) {
        paymentDate = _parseDate(payment['processedAt']);
      }

      // If still no date, use current time as fallback
      paymentDate ??= DateTime.now();

      // Generate a payment ID for display
      String displayPaymentId = '';
      if (payment['invoiceId'] != null) {
        displayPaymentId = payment['invoiceId'].toString();
      } else if (payment['transactionId'] != null) {
        final txnId = payment['transactionId'].toString();
        displayPaymentId = 'TXN-${txnId.length > 8 ? txnId.substring(0, 8) : txnId}';
      } else if (payment['_id'] != null) {
        final id = payment['_id'].toString();
        displayPaymentId = 'PAY-${id.length > 6 ? id.substring(0, 6) : id}';
      } else {
        displayPaymentId = 'PAY-${DateFormat('yyMMdd').format(paymentDate)}';
      }

      // Build reference string
      String reference = '';
      if (payment['transactionId'] != null) {
        reference = 'TXN: ${payment['transactionId']}';
      } else if (payment['invoiceId'] != null) {
        reference = 'INV: ${payment['invoiceId']}';
      } else if (payment['referenceId'] != null) {
        reference = 'REF: ${payment['referenceId']}';
      }

      // Map payment method to expected format
      String method = 'Mobile Money';
      if (payment['paymentMethod'] != null) {
        final rawMethod = payment['paymentMethod'].toString().toLowerCase();
        if (rawMethod.contains('evc')) {
          method = 'EVC Plus';
        } else if (rawMethod.contains('edahab') || rawMethod.contains('e-dahab')) {
          method = 'E-Dahab';
        } else if (rawMethod.contains('cash')) {
          method = 'Cash';
        } else if (rawMethod.contains('bank')) {
          method = 'Bank Transfer';
        }
      }

      return {
        'paymentId': displayPaymentId,
        'amount': _toDouble(payment['amount']),
        'date': paymentDate,
        'method': method,
        'reference': reference,
      };
    } catch (e) {
      print('⚠️ Error processing payment object: $e');
      return null;
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

  Future<void> _refreshLoanDetails() async {
    setState(() => _isRefreshing = true);
    await _loadLoanDetails();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.primaryGreen;
      case 'overdue':
        return Colors.orange;
      case 'completed':
        return Colors.grey;
      case 'pending':
        return Colors.blue;
      case 'approved':
        return Colors.purple;
      case 'rejected':
        return Colors.red;
      default:
        return AppColors.primaryGreen;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'overdue':
        return 'Overdue';
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending Approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  double _getProgress() {
    if (_loan.isEmpty) return 0.0;
    final paid = _toDouble(_loan['paidAmount']);
    final total = _toDouble(_loan['amount']);
    if (total == 0) return 0.0;
    return paid / total;
  }

  int _getPaidInstallments() {
    if (_schedule.isEmpty) return 0;
    return _schedule.where((s) => s['status']?.toString().toLowerCase() == 'paid').length;
  }

  int _getTotalInstallments() {
    return _schedule.length;
  }

  Map<String, dynamic>? _getNextPendingInstallment() {
    if (_schedule.isEmpty) return null;
    try {
      return _schedule.firstWhere(
            (s) => s['status']?.toString().toLowerCase() == 'pending',
      );
    } catch (e) {
      return null;
    }
  }

  double _getNextPaymentAmount() {
    final next = _getNextPendingInstallment();
    if (next == null) return 0.0;
    return _toDouble(next['amount']);
  }

  DateTime? _getNextPaymentDate() {
    final next = _getNextPendingInstallment();
    if (next == null) return null;
    return _parseDate(next['dueDate']);
  }

  List<PieChartSectionData> _getPaymentChartSections() {
    final paid = _toDouble(_loan['paidAmount']);
    final total = _toDouble(_loan['amount']);
    final remaining = total - paid;

    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          title: 'No Data',
          color: Colors.grey.shade300,
          radius: 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ];
    }

    if (paid == 0) {
      return [
        PieChartSectionData(
          value: 1,
          title: '0%',
          color: Colors.orange.shade300,
          radius: 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ];
    }

    return [
      if (paid > 0)
        PieChartSectionData(
          value: paid,
          title: '${(paid / total * 100).toStringAsFixed(1)}%',
          color: AppColors.primaryGreen,
          radius: 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      if (remaining > 0)
        PieChartSectionData(
          value: remaining,
          title: '${(remaining / total * 100).toStringAsFixed(1)}%',
          color: Colors.orange.shade300,
          radius: 50,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final status = _loan['status']?.toString().toLowerCase() ?? 'pending';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading && !_isRefreshing
          ? _buildLoadingShimmer()
          : RefreshIndicator(
        onRefresh: _refreshLoanDetails,
        color: AppColors.primaryGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              floating: false,
              snap: false,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
              elevation: 4,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 70, bottom: 16),
                title: Text(
                  _loan['loanId'] ?? 'Loan Details',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                background: _buildHeaderBackground(),
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
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home, size: 18),
                            SizedBox(width: 4),
                            Text('Overview'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.schedule, size: 18),
                            SizedBox(width: 4),
                            Text('Schedule'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, size: 18),
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

            SliverFillRemaining(
              child: Container(
                color: Colors.white,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
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

  Widget _buildHeaderBackground() {
    final status = _loan['status']?.toString().toLowerCase() ?? 'pending';
    final statusColor = _getStatusColor(status);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [statusColor, statusColor.withOpacity(0.8)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 70),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Loan Amount',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormat.format(_toDouble(_loan['amount'])),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          status == 'overdue' ? Icons.warning : Icons.circle,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusText(status),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          height: 200,
          color: Colors.grey[300],
        ),
        const SizedBox(height: 20),
        ...List.generate(5, (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final status = _loan['status']?.toString().toLowerCase() ?? 'pending';
    final nextPaymentDate = _getNextPaymentDate();
    final nextPaymentAmount = _getNextPaymentAmount();
    final paidInstallments = _getPaidInstallments();
    final totalInstallments = _getTotalInstallments();
    final progress = _getProgress();
    final paidAmount = _toDouble(_loan['paidAmount']);
    final totalAmount = _toDouble(_loan['amount']);
    final remainingAmount = totalAmount - paidAmount;
    final borrower = _loan['borrower'] ?? {};

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
                    colors: [
                      _getStatusColor(status).withOpacity(0.7),
                      _getStatusColor(status),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    borrower['initials'] ??
                        (borrower['name'] != null
                            ? borrower['name'][0].toUpperCase()
                            : 'B'),
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
                      borrower['name'] ?? 'Borrower',
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

        // Payment Chart Card
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 120,
                      child: PieChart(
                        PieChartData(
                          sections: _getPaymentChartSections(),
                          centerSpaceRadius: 30,
                          sectionsSpace: 2,
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem('Paid', AppColors.primaryGreen, paidAmount),
                        const SizedBox(height: 12),
                        _buildLegendItem('Remaining', Colors.orange.shade300, remainingAmount),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Progress Card
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Repayment Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildAmountColumn('Paid', paidAmount)),
                  Expanded(child: _buildAmountColumn('Remaining', remainingAmount)),
                ],
              ),
              const SizedBox(height: 16),
              Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Container(
                    height: 10,
                    width: MediaQuery.of(context).size.width * 0.7 * progress,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryGreen, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(1)}% Complete',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (totalInstallments > 0)
                    Text(
                      '$paidInstallments/$totalInstallments installments',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Key Information Grid
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Loan Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildInfoTile(
                    Icons.calendar_today,
                    'Start Date',
                    _loan['startDate'] != null ? _dateFormat.format(DateTime.parse(_loan['startDate'])) : 'N/A',
                  ),
                  _buildInfoTile(
                    Icons.event,
                    'End Date',
                    _loan['endDate'] != null ? _dateFormat.format(DateTime.parse(_loan['endDate'])) : 'N/A',
                  ),
                  _buildInfoTile(Icons.percent, 'Interest', '${_loan['interestRate'] ?? 0}%'),
                  _buildInfoTile(Icons.access_time, 'Term', '${_loan['term'] ?? 0} months'),
                  _buildInfoTile(Icons.repeat, 'Frequency', _loan['paymentFrequency'] ?? 'Monthly'),
                  _buildInfoTile(Icons.payments, 'Installments', '$paidInstallments/$totalInstallments'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Next Payment Card
        if ((status == 'active' || status == 'overdue') && nextPaymentAmount > 0)
          _buildCard(
            color: status == 'overdue' ? Colors.orange.withOpacity(0.1) : AppColors.primaryGreen.withOpacity(0.1),
            borderColor: status == 'overdue' ? Colors.orange : AppColors.primaryGreen,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: status == 'overdue' ? Colors.orange : AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    status == 'overdue' ? Icons.warning_amber_rounded : Icons.calendar_month,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status == 'overdue' ? 'Overdue Payment' : 'Next Payment',
                        style: TextStyle(
                          fontSize: 14,
                          color: status == 'overdue' ? Colors.orange : AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormat.format(nextPaymentAmount),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: status == 'overdue' ? Colors.orange : AppColors.textPrimary,
                        ),
                      ),
                      if (nextPaymentDate != null)
                        Text(
                          'Due: ${_dateFormat.format(nextPaymentDate)}',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Recent Payments Preview (if any)
        if (_payments.isNotEmpty)
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Payments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    TextButton(
                      onPressed: () {
                        _tabController.animateTo(2); // Switch to payments tab
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._payments.take(3).map((payment) => _buildRecentPaymentPreview(payment)),
              ],
            ),
          ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildRecentPaymentPreview(Map<String, dynamic> payment) {
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
              Icons.check_circle,
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
                  _currencyFormat.format(payment['amount']),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  date != null ? '${_dateFormat.format(date)} • ${_timeFormat.format(date)}' : 'Date unknown',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              payment['method'] ?? 'Payment',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child, Color? color, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: borderColor != null ? Border.all(color: borderColor, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLegendItem(String label, Color color, dynamic amount) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(_currencyFormat.format(_toDouble(amount)),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountColumn(String label, dynamic amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(_currencyFormat.format(_toDouble(amount)),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleTab() {
    if (_schedule.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No payment schedule available',
              style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _schedule.length,
      itemBuilder: (context, index) {
        final installment = _schedule[index];
        final dueDate = _parseDate(installment['dueDate']);

        if (dueDate == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InstallmentTile(
            installmentNo: installment['installmentNo'] ?? index + 1,
            dueDate: dueDate,
            amount: _toDouble(installment['amount']),
            principal: _toDouble(installment['principal']),
            interest: _toDouble(installment['interest']),
            status: installment['status']?.toString().toLowerCase() ?? 'pending',
            isLast: index == _schedule.length - 1,
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
            Icon(Icons.payment, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No payments recorded yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Payments will appear here once processed',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        final paymentDate = payment['date'] as DateTime?;

        if (paymentDate == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PaymentTile(
            paymentId: payment['paymentId'] ?? 'PAY-${index + 1}',
            amount: _toDouble(payment['amount']),
            date: paymentDate,
            method: payment['method'] ?? 'Mobile Money',
            reference: payment['reference'],
            isLast: index == _payments.length - 1,
          ),
        );
      },
    );
  }
}