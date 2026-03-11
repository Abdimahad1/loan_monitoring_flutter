// guarantor_screens/guarantor_loans_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../services/api_service.dart';
import '../utils/app_constants.dart';
import 'guarantor_loan_details_screen.dart';

class GuarantorLoansScreen extends StatefulWidget {
  const GuarantorLoansScreen({super.key});

  @override
  State<GuarantorLoansScreen> createState() => _GuarantorLoansScreenState();
}

class _GuarantorLoansScreenState extends State<GuarantorLoansScreen> {
  int _selectedFilter = 0;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;

  List<dynamic> _allLoans = [];
  Map<String, dynamic> _pagination = {
    'page': 1,
    'limit': 10,
    'total': 0,
    'pages': 1
  };

  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$');
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  final List<String> _filters = ['All', 'Active', 'Overdue', 'Completed'];

  @override
  void initState() {
    super.initState();
    _loadLoans(reset: true);

    // Add scroll listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          !_isLoadingMore &&
          _hasMore) {
        _loadMoreLoans();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLoans({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
      });
    }

    try {
      String? statusParam;
      if (_selectedFilter > 0) {
        statusParam = _filters[_selectedFilter].toLowerCase();
      }

      final result = await _apiService.getGuarantorLoans(
        page: _currentPage,
        limit: 10,
        status: statusParam,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (mounted) {
        if (result['success']) {
          setState(() {
            final newLoans = result['data'] ?? [];

            if (reset) {
              _allLoans = newLoans;
            } else {
              _allLoans.addAll(newLoans);
            }

            _pagination = result['pagination'] ?? {
              'page': _currentPage,
              'limit': 10,
              'total': _allLoans.length,
              'pages': 1
            };

            _hasMore = _currentPage < (_pagination['pages'] ?? 1);
            _isLoading = false;
            _isLoadingMore = false;
          });
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isLoadingMore = false;
            });
            _showErrorSnackBar(result['message'] ?? 'Failed to load loans');
          }
        }
      }
    } catch (e) {
      print('❌ Error loading loans: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        _showErrorSnackBar('Failed to load loans. Please try again.');
      }
    }
  }

  Future<void> _loadMoreLoans() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _loadLoans(reset: false);
  }

  Future<void> _refreshLoans() async {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _currentPage = 1;
    });
    await _loadLoans(reset: true);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _currentPage = 1;
    });
    _loadLoans(reset: true);
  }

  void _onFilterSelected(int index) {
    setState(() {
      _selectedFilter = index;
      _currentPage = 1;
    });
    _loadLoans(reset: true);
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.primaryGreen;
      case 'overdue':
        return Colors.red;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getRiskColor(String? risk) {
    switch (risk?.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Loans You Guarantee'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by loan ID or borrower...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLoans,
        color: AppColors.primaryGreen,
        child: Column(
          children: [
            // Filter Chips
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _selectedFilter == index,
                      label: Text(_filters[index]),
                      onSelected: (selected) {
                        _onFilterSelected(selected ? index : 0);
                      },
                      backgroundColor: Colors.white,
                      selectedColor: _getStatusColor(_filters[index].toLowerCase()),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _selectedFilter == index
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Results Count
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_pagination['total']} loan${_pagination['total'] != 1 ? 's' : ''} found',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 12, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'View Only • No Actions',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Loans List
            Expanded(
              child: _isLoading
                  ? _buildLoadingShimmer()
                  : _allLoans.isEmpty
                  ? _buildEmptyState()
                  : AnimationLimiter(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _allLoans.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _allLoans.length) {
                      return _buildLoadingMoreIndicator();
                    }

                    final loan = _allLoans[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 500),
                      child: SlideAnimation(
                        verticalOffset: 50,
                        child: FadeInAnimation(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildLoanCard(loan),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan) {
    final status = loan['status']?.toString().toLowerCase() ?? 'unknown';
    final risk = loan['risk']?['level']?.toString().toLowerCase() ?? 'low';
    final progress = loan['progress'] ?? 0.0;
    final statusColor = _getStatusColor(status);
    final riskColor = _getRiskColor(risk);
    final borrower = loan['borrower'] ?? {};
    final nextPayment = loan['nextPayment'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GuarantorLoanDetailsScreen(loanId: loan['_id']),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header Row
                Row(
                  children: [
                    // Borrower Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.7),
                            statusColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          borrower['initials'] ?? 'UN',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Borrower & Loan Info
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
                          Row(
                            children: [
                              Text(
                                loan['loanId'] ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${loan['term'] ?? 0} months',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status & Risk Badges
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: riskColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'RISK: ${risk.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: riskColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Amount & Progress
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Loan Amount',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFormat.format(loan['amount'] ?? 0),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(progress * 100).toInt()}% repaid',
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Paid: ${_currencyFormat.format(loan['paidAmount'] ?? 0)}',
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

                const SizedBox(height: 12),

                // Progress Bar
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 8,
                      width: MediaQuery.of(context).size.width * 0.6 * progress,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            status == 'overdue' ? Colors.orange : AppColors.primaryGreen,
                            status == 'overdue' ? Colors.red : AppColors.primaryLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Loan Details Grid
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Start Date',
                          loan['startDate'] != null
                              ? _dateFormat.format(DateTime.parse(loan['startDate']))
                              : 'N/A',
                          Icons.calendar_today,
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'End Date',
                          loan['endDate'] != null
                              ? _dateFormat.format(DateTime.parse(loan['endDate']))
                              : 'N/A',
                          Icons.event,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Next Payment or Overdue Warning
                if (nextPayment != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: status == 'overdue'
                          ? Colors.red.withOpacity(0.05)
                          : Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: status == 'overdue'
                            ? Colors.red.withOpacity(0.3)
                            : Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          status == 'overdue'
                              ? Icons.warning_amber_rounded
                              : Icons.calendar_month,
                          size: 16,
                          color: status == 'overdue' ? Colors.red : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status == 'overdue'
                                    ? 'Overdue Payment'
                                    : 'Next Payment',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: status == 'overdue' ? Colors.red : Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                status == 'overdue'
                                    ? 'Due on ${_dateFormat.format(DateTime.parse(nextPayment['dueDate']))}'
                                    : _dateFormat.format(DateTime.parse(nextPayment['dueDate'])),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: status == 'overdue'
                                      ? Colors.red.shade700
                                      : Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _currencyFormat.format(nextPayment['amount'] ?? 0),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: status == 'overdue' ? Colors.red : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'No loans to display',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _selectedFilter == 0
                  ? 'You are not guaranteeing any loans yet'
                  : 'No ${_filters[_selectedFilter].toLowerCase()} loans found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
        ),
      ),
    );
  }
}