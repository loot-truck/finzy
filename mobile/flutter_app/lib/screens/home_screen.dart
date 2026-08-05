import 'package:flutter/material.dart';

import '../data/static_data.dart';
import '../theme/clay_theme.dart';
import '../widgets/clay_surface.dart';
import '../widgets/pop_it.dart';
import 'scan_screen.dart';

/// Style F — Home / expense tracker.
///
/// Everything you read is carved into the canvas; everything you tap is a
/// silicone bubble that drops into its socket when pressed.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openScanner(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => const ScanScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Clay.canvas,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 130),
              children: [
                const _Header(),
                const SizedBox(height: 16),
                const _SpendHero(),
                const SizedBox(height: 16),
                _QuickActions(onScan: () => _openScanner(context)),
                const SizedBox(height: 16),
                const _CategoryCard(),
                const SizedBox(height: 16),
                const _Transactions(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomNav(onScan: () => _openScanner(context)),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back', style: Clay.label),
              SizedBox(height: 2),
              Text(kUserName, style: Clay.title),
            ],
          ),
        ),
        PopIt.circle(
          size: 46,
          onTap: () {},
          child: const Icon(Icons.person_rounded, size: 20, color: Clay.dim),
        ),
      ],
    );
  }
}

/// The one saturated surface on the screen. Still recessed — you read it, you
/// do not tap it.
class _SpendHero extends StatelessWidget {
  const _SpendHero();

  @override
  Widget build(BuildContext context) {
    return ClaySurface(
      radius: BorderRadius.circular(40),
      color: Clay.accent,
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 20),
      innerShadows: [
        InnerShadow(
          color: Clay.shadowAccent.withValues(alpha: 0.55),
          offset: const Offset(7, 8),
          blur: 14,
        ),
        InnerShadow(
          color: Colors.white.withValues(alpha: 0.45),
          offset: const Offset(-7, -8),
          blur: 14,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spent this month',
            style: TextStyle(fontSize: 12, color: Clay.onAccentDim),
          ),
          const SizedBox(height: 4),
          Text(Money.format(kSummary.spent), style: Clay.displayLarge),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClayTrack(
                  value: kSummary.progress,
                  fill: Colors.white,
                  background: const Color(0xFF5B4FD0),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${kSummary.percent}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Clay.onAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${Money.format(kSummary.remaining)} left of your '
            '${Money.format(kSummary.budget)} budget',
            style: const TextStyle(fontSize: 11, color: Clay.onAccentDim),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final action in kQuickActions) ...[
          Expanded(
            child: Column(
              children: [
                PopIt.circle(
                  size: 54,
                  onTap: action.label == 'Scan' ? onScan : () {},
                  child: Icon(action.icon, size: 20, color: Clay.accent),
                ),
                const SizedBox(height: 8),
                Text(action.label, style: Clay.caption),
              ],
            ),
          ),
          if (action != kQuickActions.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard();

  @override
  Widget build(BuildContext context) {
    return Recessed(
      radius: 32,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Where it went', style: Clay.sectionTitle),
              Text(kSummary.month, style: Clay.caption),
            ],
          ),
          const SizedBox(height: 14),
          for (final c in kCategories) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(c.label, style: Clay.label),
                Text(
                  Money.format(c.amount),
                  style: Clay.label.copyWith(
                    color: Clay.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClayTrack(
              value: c.share,
              fill: Clay.accent.withValues(alpha: 0.35 + 0.65 * c.share),
            ),
            if (c != kCategories.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _Transactions extends StatelessWidget {
  const _Transactions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent', style: Clay.sectionTitle),
            Text(
              'See all',
              style: Clay.label.copyWith(
                color: Clay.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final t in kTransactions) ...[
          PressableRecess(
            onTap: () {},
            radius: 26,
            padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
            child: Row(
              children: [
                PopIt.circle(
                  size: 40,
                  inset: 3,
                  tone: t.incoming ? PopTone.accent : PopTone.soft,
                  child: Icon(
                    t.icon,
                    size: 16,
                    color: t.incoming ? Colors.white : Clay.ink,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: Clay.bodyMedium),
                      const SizedBox(height: 2),
                      Text(t.subtitle, style: Clay.caption),
                    ],
                  ),
                ),
                Text(
                  '${t.incoming ? '+' : '−'}${Money.format(t.amount)}',
                  style: Clay.amount.copyWith(
                    color: t.incoming ? Clay.accent : Clay.ink,
                  ),
                ),
              ],
            ),
          ),
          if (t != kTransactions.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Recessed nav bar with the scan bubble raised out of it — the one place the
/// two treatments meet, which is what makes the FAB read as primary.
class _BottomNav extends StatefulWidget {
  const _BottomNav({required this.onScan});

  final VoidCallback onScan;

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav> {
  int _index = 0;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.bar_chart_rounded, 'Stats'),
    (Icons.credit_card_rounded, 'Cards'),
    (Icons.person_rounded, 'You'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: SizedBox(
        height: 74,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Recessed(
              radius: 35,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _navItem(0),
                  _navItem(1),
                  const SizedBox(width: 72),
                  _navItem(2),
                  _navItem(3),
                ],
              ),
            ),
            Positioned(
              top: -6,
              child: PopIt.circle(
                size: 72,
                inset: 5,
                tone: PopTone.accent,
                onTap: widget.onScan,
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int i) {
    final selected = _index == i;
    final (icon, label) = _items[i];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _index = i),
      child: SizedBox(
        width: 46,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Clay.accent : Clay.dim.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Clay.accent : Clay.dim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
