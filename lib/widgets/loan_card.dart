import 'package:flutter/material.dart';
import '../utils/app_constants.dart';

class LoanCard extends StatelessWidget {
  final String loanId;
  final double amount;
  final String status;
  final double progress;
  final VoidCallback onTap;

  const LoanCard({
    super.key,
    required this.loanId,
    required this.amount,
    required this.status,
    required this.progress,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (status) {
      case 'active':
        return AppColors.primaryGreen;
      case 'overdue':
        return Colors.orange;
      case 'completed':
        return Colors.grey;
      case 'pending':
        return Colors.blue;
      default:
        return AppColors.primaryGreen;
    }
  }

  String _getStatusText() {
    return status.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: status == 'overdue'
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loanId,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "\$${amount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Container(
                          height: 6,
                          width: MediaQuery.of(context).size.width * 0.4 * progress,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryGreen,
                                AppColors.primaryLight,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${(progress * 100).toInt()}%",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
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
}

class LoanGridCard extends StatelessWidget {
  final String loanId;
  final double amount;
  final String status;
  final double progress;
  final int term;
  final double interest;
  final VoidCallback onTap;

  const LoanGridCard({
    super.key,
    required this.loanId,
    required this.amount,
    required this.status,
    required this.progress,
    required this.term,
    required this.interest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = AppColors.primaryGreen;
        break;
      case 'overdue':
        statusColor = Colors.orange;
        break;
      case 'completed':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = AppColors.primaryGreen;
    }

    return Container(
      height: 170, // Fixed height to prevent overflow
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(12), // Slightly reduced padding
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: status == 'overdue'
                    ? Colors.orange.withOpacity(0.3)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status and more button row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 8, // Smaller font
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.more_horiz,
                      size: 14, // Smaller icon
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Amount
                Text(
                  "\$${amount.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 16, // Smaller font
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),

                // Loan ID (with ellipsis if too long)
                Text(
                  loanId,
                  style: TextStyle(
                    fontSize: 9, // Smaller font
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Term and Interest row
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem("Term", "$term months"),
                    ),
                    Expanded(
                      child: _buildInfoItem("Interest", "$interest%"),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Progress bar
                Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Container(
                            height: 4,
                            width: double.infinity * progress,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryGreen,
                                  AppColors.primaryLight,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${(progress * 100).toInt()}%",
                      style: TextStyle(
                        fontSize: 9, // Smaller font
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8, // Smaller font
            color: AppColors.textSecondary.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 9, // Smaller font
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}