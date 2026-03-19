// guarantor_screens/guarantor_statistics_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/app_constants.dart';

class GuarantorStatisticsScreen extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<dynamic>? guaranteedLoans;

  const GuarantorStatisticsScreen({
    super.key,
    required this.stats,
    this.guaranteedLoans,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    // Stats from the guarantor dashboard
    final totalGuaranteed = stats['totalGuaranteed'] ?? 0;
    final activeLoans = stats['activeLoans'] ?? 0;
    final overdueLoans = stats['overdueLoans'] ?? 0;
    final completedLoans = stats['completedLoans'] ?? 0;
    final totalAmount = (stats['totalAmount'] ?? 0).toDouble();
    final atRiskAmount = (stats['atRiskAmount'] ?? 0).toDouble();
    final paidAmount = (stats['paidAmount'] ?? 0).toDouble();

    // Calculate derived stats
    final remainingAmount = totalAmount - paidAmount;
    final atRiskPercentage = totalAmount > 0
        ? (atRiskAmount / totalAmount * 100)
        : 0;
    final repaidPercentage = totalAmount > 0
        ? (paidAmount / totalAmount * 100)
        : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Guarantor Statistics',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Summary Cards
              _buildSummaryCard(
                'Total Guaranteed',
                totalGuaranteed.toString(),
                Icons.shield,
                Colors.blue,
                subtitle: '$activeLoans active • $completedLoans completed',
              ),
              const SizedBox(height: 12),

              _buildSummaryCard(
                'Total Amount',
                currencyFormat.format(totalAmount),
                Icons.attach_money,
                AppColors.primaryGreen,
                subtitle: 'Across all guaranteed loans',
              ),
              const SizedBox(height: 12),

              _buildSummaryCard(
                'Amount Repaid',
                currencyFormat.format(paidAmount),
                Icons.payment,
                Colors.green,
                subtitle: '${repaidPercentage.toStringAsFixed(1)}% of total',
              ),
              const SizedBox(height: 12),

              _buildSummaryCard(
                'At Risk Amount',
                currencyFormat.format(atRiskAmount),
                Icons.warning_amber_rounded,
                Colors.red,
                subtitle: '${atRiskPercentage.toStringAsFixed(1)}% of total',
              ),

              const SizedBox(height: 24),

              // Risk Exposure Chart
              if (totalAmount > 0)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Risk Exposure',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 150,
                              child: PieChart(
                                PieChartData(
                                  sections: [
                                    PieChartSectionData(
                                      value: paidAmount,
                                      title: 'Safe',
                                      color: Colors.green,
                                      radius: 50,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (atRiskAmount > 0)
                                      PieChartSectionData(
                                        value: atRiskAmount,
                                        title: 'At Risk',
                                        color: Colors.red,
                                        radius: 50,
                                        titleStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    if (remainingAmount - atRiskAmount > 0)
                                      PieChartSectionData(
                                        value: remainingAmount - atRiskAmount,
                                        title: 'Active',
                                        color: Colors.orange.shade300,
                                        radius: 50,
                                        titleStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                  centerSpaceRadius: 40,
                                  sectionsSpace: 2,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLegendItem('Safe (Paid)', Colors.green, paidAmount),
                                const SizedBox(height: 8),
                                _buildLegendItem('Active', Colors.orange.shade300,
                                    remainingAmount - atRiskAmount),
                                const SizedBox(height: 8),
                                _buildLegendItem('At Risk', Colors.red, atRiskAmount),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Loan Status Grid
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Guaranteed Loans Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusCard(
                            'Total',
                            totalGuaranteed.toString(),
                            Icons.shield,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatusCard(
                            'Active',
                            activeLoans.toString(),
                            Icons.trending_up,
                            AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusCard(
                            'Completed',
                            completedLoans.toString(),
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatusCard(
                            'Overdue',
                            overdueLoans.toString(),
                            Icons.warning,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Risk Summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Risk Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildRiskIndicator(
                      'Overall Risk Level',
                      atRiskPercentage,
                      _getRiskLevel(atRiskPercentage),
                      _getRiskColor(atRiskPercentage),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: atRiskAmount > 0
                            ? Colors.red.withOpacity(0.05)
                            : Colors.green.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: atRiskAmount > 0
                              ? Colors.red.withOpacity(0.3)
                              : Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            atRiskAmount > 0
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle,
                            color: atRiskAmount > 0 ? Colors.red : Colors.green,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  atRiskAmount > 0
                                      ? 'You have exposure to risk'
                                      : 'No current risk exposure',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: atRiskAmount > 0 ? Colors.red : Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  atRiskAmount > 0
                                      ? '$overdueLoans overdue loan${overdueLoans > 1 ? 's' : ''} totaling ${currencyFormat.format(atRiskAmount)}'
                                      : 'All guaranteed loans are in good standing',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: atRiskAmount > 0
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
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
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, double amount) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                currencyFormat.format(amount),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRiskIndicator(String label, double percentage, String level, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
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
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                level,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
              width: percentage.clamp(0, 100) * 3, // Scale for visualization
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green,
                    percentage > 30 ? Colors.orange : Colors.green,
                    percentage > 60 ? Colors.red : Colors.orange,
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${percentage.toStringAsFixed(1)}% of total amount at risk',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getRiskLevel(double percentage) {
    if (percentage < 10) return 'Low Risk';
    if (percentage < 25) return 'Medium Risk';
    if (percentage < 50) return 'High Risk';
    return 'Critical Risk';
  }

  Color _getRiskColor(double percentage) {
    if (percentage < 10) return Colors.green;
    if (percentage < 25) return Colors.orange;
    if (percentage < 50) return Colors.red;
    return Colors.purple;
  }
}