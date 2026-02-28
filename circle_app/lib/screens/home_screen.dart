import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'groups_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';
import 'join_room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const GroupsScreen(),
    const FriendsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (index == 3) {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const JoinRoomScreen()));
              return;
            }
            setState(() => _currentIndex = index);
          },
          destinations: [
            _buildNavDestination(
              Icons.group_outlined,
              Icons.group_rounded,
              'Groups',
              0,
            ),
            _buildNavDestination(
              Icons.people_outlined,
              Icons.people_rounded,
              'Friends',
              1,
            ),
            _buildNavDestination(
              Icons.person_outlined,
              Icons.person_rounded,
              'Profile',
              2,
            ),
            _buildNavDestination(
              Icons.music_note_outlined,
              Icons.music_note_rounded,
              'Music',
              3,
            ),
          ],
        ),
      ),
    );
  }

  NavigationDestination _buildNavDestination(
    IconData icon,
    IconData selectedIcon,
    String label,
    int index,
  ) {
    final isSelected = _currentIndex == index;
    return NavigationDestination(
      icon: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.textMuted,
      ),
      selectedIcon: Icon(selectedIcon, color: AppColors.primary),
      label: label,
    );
  }
}
