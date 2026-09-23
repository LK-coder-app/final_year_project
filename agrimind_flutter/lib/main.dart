// ═══════════════════════════════════════════════════════════════════
// AgriMind Flutter App — Main Entry Point
// ═══════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'theme.dart';
import 'screens/farmer_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/architecture_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const AgriMindApp(),
    ),
  );
}

class AgriMindApp extends StatelessWidget {
  const AgriMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriMind — AI Agricultural Requirements',
      theme: AgriTheme.dark,
      debugShowCheckedModeBanner: false,
      home: const _MainShell(),
    );
  }
}

// ── Main Shell with side navigation ──────────────────────────────
class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _selectedIndex = 0;

  final _screens = const [
    FarmerScreen(),
    DashboardScreen(),
    ArchitectureScreen(),
  ];

  final _navItems = const [
    _NavItem(icon: '🌾', label: 'Farmer Portal'),
    _NavItem(icon: '📊', label: 'Company Dashboard'),
    _NavItem(icon: '🏗️', label: 'System Architecture'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AgriColors.bgGradient),
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: isWide
                  ? Row(
                      children: [
                        _buildSideNav(),
                        Expanded(child: _screens[_selectedIndex]),
                      ],
                    )
                  : _screens[_selectedIndex],
            ),
          ],
        ),
      ),
      bottomNavigationBar: isWide ? null : _buildBottomNav(),
    );
  }

  Widget _buildAppBar() {
    return Consumer<AppState>(
      builder: (ctx, state, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AgriColors.slate900.withOpacity(0.8),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          child: Row(
            children: [
              // Brand
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AgriColors.brandGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: Text('🌿', style: TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AgriMind',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AgriColors.emerald400,
                    ),
                  ),
                  Text(
                    'AI Agricultural Requirement System',
                    style: GoogleFonts.inter(fontSize: 10, color: AgriColors.slate500),
                  ),
                ],
              ),
              const Spacer(),

              // Server status indicator
              Consumer<AppState>(
                builder: (ctx, state, _) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: state.serverOnline
                        ? AgriColors.emerald500.withOpacity(0.1)
                        : AgriColors.red600.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: state.serverOnline
                          ? AgriColors.emerald700.withOpacity(0.4)
                          : AgriColors.red600.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: state.serverOnline ? AgriColors.emerald500 : AgriColors.red600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (state.serverOnline ? AgriColors.emerald500 : AgriColors.red600)
                                  .withOpacity(0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state.serverOnline ? 'Server Online' : 'Server Offline',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: state.serverOnline ? AgriColors.emerald400 : const Color(0xFFfca5a5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // LLM provider badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AgriColors.slate800,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🤖', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text(
                      _llmLabel(state.llmProvider),
                      style: GoogleFonts.inter(fontSize: 11, color: AgriColors.slate400),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSideNav() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: AgriColors.slate900.withOpacity(0.5),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ..._navItems.indexed.map((entry) {
            final (i, item) = entry;
            return _buildNavTile(item, i);
          }),
        ],
      ),
    );
  }

  Widget _buildNavTile(_NavItem item, int index) {
    final selected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AgriColors.emerald500.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AgriColors.emerald500.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Text(item.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AgriColors.emerald400 : AgriColors.slate400,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AgriColors.emerald500,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBar _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (i) => setState(() => _selectedIndex = i),
      backgroundColor: AgriColors.slate900,
      selectedItemColor: AgriColors.emerald400,
      unselectedItemColor: AgriColors.slate500,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 10),
      unselectedLabelStyle: GoogleFonts.outfit(fontSize: 10),
      items: const [
        BottomNavigationBarItem(icon: Text('🌾', style: TextStyle(fontSize: 22)), label: 'Farmer'),
        BottomNavigationBarItem(icon: Text('📊', style: TextStyle(fontSize: 22)), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Text('🏗️', style: TextStyle(fontSize: 22)), label: 'Architecture'),
      ],
    );
  }

  String _llmLabel(String p) {
    switch (p) {
      case 'gemini': return 'Gemini';
      case 'openai': return 'OpenAI';
      default: return 'Local Engine';
    }
  }
}

class _NavItem {
  final String icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
