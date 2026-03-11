import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../services/api_service.dart';
import '../utils/app_constants.dart';
import '../widgets/loan_card.dart';
import '../widgets/filter_chip.dart';
import 'loan_details_screen.dart';

class MyLoansScreen extends StatefulWidget {
  const MyLoansScreen({super.key});

  @override
  State<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends State<MyLoansScreen> {
  int _selectedFilter = 0;
  String _searchQuery = '';
  bool _isGridView = false;
  bool _isLoading = true;
  bool _isRefreshing = false;

  List<dynamic> _loans = [];
  Map<String, dynamic> _pagination = {
    'page': 1,
    'limit': 10,
    'total': 0,
    'pages': 1
  };

  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _statusFilters = ['all', 'active', 'completed', 'overdue', 'pending', 'approved', 'rejected'];

  // Helper method to safely convert any value to double
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Helper method to safely convert any value to int
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadLoans();

    // Add scroll listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
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
        _pagination['page'] = 1;
      });
    }

    try {
      // Fix: Properly handle status parameter
      String? statusParam;
      if (_selectedFilter > 0) {
        final selectedStatus = _statusFilters[_selectedFilter];
        // Don't pass 'all' to API, only pass specific statuses
        if (selectedStatus != 'all') {
          statusParam = selectedStatus;
        }
      }

      final result = await _apiService.getUserLoans(
        limit: 10,
        page: _pagination['page'],
        status: statusParam,
      );

      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            final rawLoans = result['loans'] as List? ?? [];
            final List<Map<String, dynamic>> processedLoans = [];

            // Fetch payment history to calculate actual paid amounts
            _apiService.getUserPaymentHistory(limit: 100).then((paymentsResult) {
              Map<String, double> paidAmountByLoan = {};

              if (paymentsResult['success']) {
                final payments = paymentsResult['payments'] as List? ?? [];

                // Calculate total paid amount per loan from successful payments
                for (var payment in payments) {
                  if (payment is Map<String, dynamic>) {
                    final paymentLoanId = payment['loanId']?.toString();
                    final status = payment['status']?.toString().toLowerCase();

                    if (paymentLoanId != null && status == 'success') {
                      final amount = _toDouble(payment['amount']);
                      paidAmountByLoan[paymentLoanId] =
                          (paidAmountByLoan[paymentLoanId] ?? 0) + amount;
                    }
                  }
                }
              }

              // Process loans with actual paid amounts
              for (var loan in rawLoans) {
                if (loan is Map<String, dynamic>) {
                  final processedLoan = Map<String, dynamic>.from(loan);

                  double amount = _toDouble(processedLoan['amount']);

                  // Get paid amount from payments data
                  String loanId = processedLoan['_id']?.toString() ?? '';
                  double paidAmount = paidAmountByLoan[loanId] ?? 0;

                  // If no payments found, try to calculate from schedule
                  if (paidAmount == 0 && processedLoan['schedule'] is List) {
                    final schedule = processedLoan['schedule'] as List;

                    int paidInstallments = schedule.where((s) {
                      final status = s['status']?.toString().toLowerCase();
                      return status == 'paid' || status == 'completed';
                    }).length;

                    if (schedule.isNotEmpty) {
                      double installmentAmount = amount / schedule.length;
                      paidAmount = installmentAmount * paidInstallments;
                    }
                  }

                  processedLoan['paidAmount'] = paidAmount;
                  processedLoan['remainingAmount'] = amount - paidAmount;
                  processedLoans.add(processedLoan);
                }
              }

              // Update UI with processed loans
              setState(() {
                if (reset) {
                  _loans = processedLoans;
                } else {
                  _loans.addAll(processedLoans);
                }

                // Update pagination
                _pagination = {
                  'page': result['pagination']?['page'] ?? (reset ? 1 : _pagination['page']),
                  'limit': result['pagination']?['limit'] ?? 10,
                  'total': result['pagination']?['total'] ?? _loans.length,
                  'pages': result['pagination']?['pages'] ?? 1,
                };

                _isLoading = false;
                _isRefreshing = false;
              });
            }).catchError((e) {
              // Fallback to basic processing if payment fetch fails
              for (var loan in rawLoans) {
                if (loan is Map<String, dynamic>) {
                  final processedLoan = Map<String, dynamic>.from(loan);
                  double amount = _toDouble(processedLoan['amount']);
                  double paidAmount = _toDouble(processedLoan['paidAmount']);

                  if (paidAmount == 0 && processedLoan['schedule'] is List) {
                    final schedule = processedLoan['schedule'] as List;
                    int paidInstallments = schedule.where((s) {
                      final status = s['status']?.toString().toLowerCase();
                      return status == 'paid' || status == 'completed';
                    }).length;

                    if (schedule.isNotEmpty) {
                      double installmentAmount = amount / schedule.length;
                      paidAmount = installmentAmount * paidInstallments;
                    }
                  }

                  processedLoan['paidAmount'] = paidAmount;
                  processedLoan['remainingAmount'] = amount - paidAmount;
                  processedLoans.add(processedLoan);
                }
              }

              setState(() {
                if (reset) {
                  _loans = processedLoans;
                } else {
                  _loans.addAll(processedLoans);
                }

                _pagination = {
                  'page': result['pagination']?['page'] ?? (reset ? 1 : _pagination['page']),
                  'limit': result['pagination']?['limit'] ?? 10,
                  'total': result['pagination']?['total'] ?? _loans.length,
                  'pages': result['pagination']?['pages'] ?? 1,
                };

                _isLoading = false;
                _isRefreshing = false;
              });
            });
          } else {
            // Handle error
            _isLoading = false;
            _isRefreshing = false;
          }
        });
      }
    } catch (e) {
      print('Error loading loans: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadMoreLoans() async {
    if (_isLoading || _isRefreshing || _pagination['page'] >= _pagination['pages']) return;

    setState(() {
      _pagination['page'] = _pagination['page'] + 1;
    });

    await _loadLoans(reset: false);
  }

  Future<void> _refreshLoans() async {
    // Don't refresh if already loading
    if (_isLoading || _isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      // Reset search when refreshing
      _searchQuery = '';
      _searchController.clear();
    });

    await _loadLoans(reset: true);
  }

  List<dynamic> get _filteredLoans {
    if (_searchQuery.isEmpty) return _loans;

    return _loans.where((loan) {
      final loanId = loan['loanId']?.toString().toLowerCase() ?? '';
      return loanId.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  int _getStatusCount(String status) {
    if (_loans.isEmpty) return 0;

    if (status == 'all') {
      return _loans.length;
    }

    try {
      final count = _loans.where((loan) {
        final loanStatus = loan['status']?.toString().toLowerCase() ?? '';
        return loanStatus == status.toLowerCase();
      }).length;

      return count;
    } catch (e) {
      print('Error counting status: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshLoans,
          color: AppColors.primaryGreen,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),

              // Search Bar
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _buildSearchBar(),
                ),
              ),

              // Filter Chips
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _buildFilterChips(),
                ),
              ),

              // View Toggle & Results Count
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _buildViewToggle(),
                ),
              ),

              // Loans Grid/List
              _isLoading && _loans.isEmpty
                  ? SliverToBoxAdapter(
                child: _buildLoadingShimmer(),
              )
                  : _filteredLoans.isEmpty
                  ? SliverToBoxAdapter(
                child: _buildEmptyState(),
              )
                  : _isGridView
                  ? _buildGridView()
                  : _buildListView(),

              // Loading more indicator
              if (_pagination['page'] < _pagination['pages'] && !_isLoading)
                SliverToBoxAdapter(
                  child: _buildLoadingMoreIndicator(),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "My Loans",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Track and manage your loans",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.filter_list_rounded,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: "Search by Loan ID",
          hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Active', 'Completed', 'Overdue', 'Pending', 'Approved', 'Rejected'];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final status = index == 0 ? 'all' : filters[index].toLowerCase();
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChipWidget(
              label: filters[index],
              count: _getStatusCount(status),
              isSelected: _selectedFilter == index,
              onSelected: () {
                setState(() {
                  _selectedFilter = index;
                });
                _refreshLoans();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "${_filteredLoans.length} loan${_filteredLoans.length != 1 ? 's' : ''} found",
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
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
          child: Row(
            children: [

            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewToggleButton(IconData icon, bool isGrid) {
    final isSelected = _isGridView == isGrid;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isGridView = isGrid;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(3, (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        )),
      ),
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.credit_card_off,
            size: 80,
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
            _selectedFilter > 0
                ? 'No ${_statusFilters[_selectedFilter]} loans at the moment'
                : 'Your loans will appear here once you have any',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final loan = _filteredLoans[index];

            double calculateProgress() {
              double paidAmount = _toDouble(loan['paidAmount']);
              double amount = _toDouble(loan['amount']);

              if (paidAmount == 0 && loan['schedule'] is List) {
                final schedule = loan['schedule'] as List;
                final paidInstallments =
                    schedule.where((s) => s['status'] == 'paid').length;

                if (schedule.isNotEmpty) {
                  final installmentAmount = amount / schedule.length;
                  paidAmount = installmentAmount * paidInstallments;
                }
              }

              if (amount == 0) return 0.0;
              return paidAmount / amount;
            }

            return Container(
              height: 170,
              child: AnimationConfiguration.staggeredGrid(
                position: index,
                duration: const Duration(milliseconds: 500),
                columnCount: 2,
                child: ScaleAnimation(
                  child: FadeInAnimation(
                    child: LoanGridCard(
                      loanId: loan['loanId'] ?? 'N/A',
                      amount: _toDouble(loan['amount']),
                      status: loan['status'] ?? 'pending',
                      progress: calculateProgress(),
                      term: _toInt(loan['term']),
                      interest: _toDouble(loan['interestRate']),
                      onTap: () {
                        _navigateToLoanDetails(loan['_id']);
                      },
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: _filteredLoans.length,
        ),
      ),
    );
  }

  SliverList _buildListView() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final loan = _filteredLoans[index];

          // Safely calculate progress
          double calculateProgress() {
            double paidAmount = _toDouble(loan['paidAmount']);
            double amount = _toDouble(loan['amount']);

            // If backend didn't send paidAmount, calculate from schedule
            if (paidAmount == 0 && loan['schedule'] is List) {
              final schedule = loan['schedule'] as List;
              final paidInstallments =
                  schedule.where((s) => s['status'] == 'paid').length;

              if (schedule.isNotEmpty) {
                final installmentAmount = amount / schedule.length;
                paidAmount = installmentAmount * paidInstallments;
              }
            }

            if (amount == 0) return 0.0;
            return paidAmount / amount;
          }

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 500),
            child: SlideAnimation(
              verticalOffset: 50,
              child: FadeInAnimation(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LoanCard(
                    loanId: loan['loanId'] ?? 'N/A',
                    amount: _toDouble(loan['amount']),
                    status: loan['status'] ?? 'pending',
                    progress: calculateProgress(),
                    onTap: () {
                      _navigateToLoanDetails(loan['_id']);
                    },
                  ),
                ),
              ),
            ),
          );
        },
        childCount: _filteredLoans.length,
      ),
    );
  }

  void _navigateToLoanDetails(String? loanId) {
    if (loanId == null || loanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid loan ID'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoanDetailsScreen(loanId: loanId),
      ),
    );
  }
}