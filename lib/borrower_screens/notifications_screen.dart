import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../utils/app_constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 1,
      'title': 'Payment Received',
      'message': 'Your payment of \$200 has been received successfully.',
      'time': DateTime.now().subtract(const Duration(hours: 2)),
      'type': 'success',
      'isRead': false,
      'action': 'View Receipt',
    },
    {
      'id': 2,
      'title': 'Upcoming Payment',
      'message': 'Next installment of \$300 is due on May 28.',
      'time': DateTime.now().subtract(const Duration(days: 1)),
      'type': 'warning',
      'isRead': false,
      'action': 'Pay Now',
    },
    {
      'id': 3,
      'title': 'Loan Approved',
      'message': 'Your loan request LN-2024-0005 has been approved.',
      'time': DateTime.now().subtract(const Duration(days: 3)),
      'type': 'info',
      'isRead': true,
      'action': 'View Details',
    },
    {
      'id': 4,
      'title': 'Loan Disbursed',
      'message': 'Your loan of \$2,000 has been disbursed to your account.',
      'time': DateTime.now().subtract(const Duration(days: 5)),
      'type': 'success',
      'isRead': true,
      'action': 'Track Funds',
    },
  ];

  int get _unreadCount {
    return _notifications.where((n) => !n['isRead']).length;
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_selectedFilter == 'Unread') {
      return _notifications.where((n) => !n['isRead']).toList();
    }
    return _notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            // Filter Tabs
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _buildFilterTabs(),
              ),
            ),

            // Notifications List
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final notification = _filteredNotifications[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 500),
                      child: SlideAnimation(
                        verticalOffset: 50,
                        child: FadeInAnimation(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildNotificationCard(notification),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _filteredNotifications.length,
                ),
              ),
            ),
          ],
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
                  "Notifications",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _unreadCount > 0
                      ? "You have $_unreadCount unread notifications"
                      : "No unread notifications",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "$_unreadCount New",
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildFilterTab('All', Icons.all_inclusive),
          _buildFilterTab('Unread', Icons.markunread),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, IconData icon) {
    final isSelected = _selectedFilter == label;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    Color color;
    IconData icon;

    switch (notification['type']) {
      case 'success':
        color = AppColors.primaryGreen;
        icon = Icons.check_circle;
        break;
      case 'warning':
        color = Colors.orange;
        icon = Icons.warning_amber;
        break;
      default:
        color = Colors.blue;
        icon = Icons.info;
    }

    final timeDiff = notification['time'];
    String timeText;

    if (timeDiff is DateTime) {
      final now = DateTime.now();
      final difference = now.difference(timeDiff);

      if (difference.inMinutes < 60) {
        timeText = '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        timeText = '${difference.inHours} hours ago';
      } else {
        timeText = '${difference.inDays} days ago';
      }
    } else {
      timeText = 'Just now';
    }

    return Container(
      decoration: BoxDecoration(
        color: notification['isRead'] ? Colors.white : AppColors.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (!notification['isRead']) {
              setState(() {
                notification['isRead'] = true;
              });
            }
            _showNotificationDetails(notification);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),

                const SizedBox(width: 15),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'],
                              style: TextStyle(
                                fontWeight: notification['isRead']
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (!notification['isRead'])
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification['message'],
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                          ),
                          if (notification['action'] != null) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                notification['action'],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
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

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
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
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                notification['title'],
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                notification['message'],
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (notification['action'] != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(notification['action']),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}