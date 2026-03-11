import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../guarantor_screens/dashboard_screen.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../borrower_screens/dashboard_screen.dart';
import '../borrower_screens/my_loans_screen.dart';
import '../borrower_screens/notifications_screen.dart';
import '../borrower_screens/payments_screen.dart';
import '../borrower_screens/profile_screen.dart';
import '../guarantor_screens/guarantor_loans_screen.dart';
import '../utils/app_constants.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await ApiService().getStoredUser();
    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  List<Widget> _getScreens() {
    if (_currentUser == null) return [];

    if (_currentUser!.isBorrower) {
      return const [
        DashboardScreen(),
        MyLoansScreen(),
        PaymentsScreen(),
        NotificationsScreen(),
        ProfileScreen(),
      ];
    } else if (_currentUser!.isGuarantor) {
      return const [
        GuarantorDashboard(),      // Your new dashboard
        GuarantorLoansScreen(),    // Your new loans list
        NotificationsScreen(),     // Common notifications
        ProfileScreen(),           // Common profile
      ];
    } else {
      // Fallback for admin (shouldn't happen in mobile app)
      return const [
        DashboardScreen(),
        NotificationsScreen(),
        ProfileScreen(),
      ];
    }
  }

  List<GButton> _getTabs() {  // Only ONE method
    if (_currentUser == null) return [];

    if (_currentUser!.isBorrower) {
      return const [
        GButton(
          icon: Icons.home_filled,
          text: 'Home',
        ),
        GButton(
          icon: Icons.credit_card,
          text: 'Loans',
        ),
        GButton(
          icon: Icons.payments,
          text: 'Payments',
        ),
        GButton(
          icon: Icons.notifications,
          text: 'Alerts',
        ),
        GButton(
          icon: Icons.person,
          text: 'Profile',
        ),
      ];
    } else if (_currentUser!.isGuarantor) {
      return const [
        GButton(
          icon: Icons.home_filled,
          text: 'Home',
        ),
        GButton(
          icon: Icons.shield,  // Changed to shield for guarantees
          text: 'Guarantees',
        ),
        GButton(
          icon: Icons.notifications,
          text: 'Alerts',
        ),
        GButton(
          icon: Icons.person,
          text: 'Profile',
        ),
      ];
    } else {
      return const [
        GButton(
          icon: Icons.home_filled,
          text: 'Home',
        ),
        GButton(
          icon: Icons.notifications,
          text: 'Alerts',
        ),
        GButton(
          icon: Icons.person,
          text: 'Profile',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
          ),
        ),
      );
    }

    final screens = _getScreens();
    final tabs = _getTabs();

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withOpacity(0.1),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: GNav(
              rippleColor: AppColors.primaryGreen.withOpacity(0.1),
              hoverColor: AppColors.primaryGreen.withOpacity(0.1),
              gap: 8,
              activeColor: Colors.white,
              iconSize: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: AppColors.primaryGreen,
              color: AppColors.textSecondary,
              tabs: tabs,
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}