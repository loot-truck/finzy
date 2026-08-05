import 'package:flutter/material.dart';

import '../theme/clay_theme.dart';

/// Hard-coded content so the UI can be built and reviewed without the backend.
/// Swap these for calls through `api/api_client.dart` when the screens are
/// signed off.

class Money {
  const Money._();
  static String format(num rupees) {
    final whole = rupees.abs().round().toString();
    // Indian grouping: last three digits, then pairs.
    if (whole.length <= 3) return '₹$whole';
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final buf = StringBuffer();
    while (rest.length > 2) {
      buf.write('${rest.substring(rest.length - 2)},');
      rest = rest.substring(0, rest.length - 2);
    }
    final groups = buf.toString().split(',').reversed.where((s) => s.isNotEmpty);
    final head = rest.isEmpty ? '' : '$rest,';
    return '₹$head${groups.join(',')}${groups.isEmpty ? '' : ','}$last3';
  }
}

class SpendSummary {
  const SpendSummary({
    required this.spent,
    required this.budget,
    required this.month,
  });

  final double spent;
  final double budget;
  final String month;

  double get remaining => budget - spent;
  double get progress => (spent / budget).clamp(0.0, 1.0);
  int get percent => (progress * 100).round();
}

class Category {
  const Category({
    required this.label,
    required this.amount,
    required this.share,
  });

  final String label;
  final double amount;
  final double share; // 0..1 of the largest category
}

class Txn {
  const Txn({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.icon,
    this.incoming = false,
  });

  final String title;
  final String subtitle;
  final double amount;
  final IconData icon;
  final bool incoming;
}

class Payee {
  const Payee({required this.name, required this.tone, required this.initial});

  final String name;
  final PopTone tone;
  final String initial;
}

class QuickAction {
  const QuickAction({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

// ---------------------------------------------------------------- the data

const kUserName = 'Sai Kumar';

const kSummary = SpendSummary(spent: 12480, budget: 20000, month: 'August');

const kQuickActions = [
  QuickAction(label: 'Scan', icon: Icons.qr_code_scanner_rounded),
  QuickAction(label: 'Send', icon: Icons.arrow_upward_rounded),
  QuickAction(label: 'Request', icon: Icons.arrow_downward_rounded),
  QuickAction(label: 'Bills', icon: Icons.receipt_long_rounded),
];

const kCategories = [
  Category(label: 'Food & dining', amount: 4320, share: 1.0),
  Category(label: 'Bills', amount: 3180, share: 0.74),
  Category(label: 'Travel', amount: 2240, share: 0.52),
];

const kTransactions = [
  Txn(
    title: 'Swiggy',
    subtitle: 'Food · 10:24 AM',
    amount: -428,
    icon: Icons.lunch_dining_rounded,
  ),
  Txn(
    title: 'Rohit Sharma',
    subtitle: 'Received · Yesterday',
    amount: 1200,
    icon: Icons.south_west_rounded,
    incoming: true,
  ),
  Txn(
    title: 'BESCOM',
    subtitle: 'Utilities · 12 Aug',
    amount: -2140,
    icon: Icons.bolt_rounded,
  ),
];

const kPayees = [
  Payee(name: 'Anu', tone: PopTone.accent, initial: 'A'),
  Payee(name: 'Kiran', tone: PopTone.accent, initial: 'K'),
  Payee(name: 'Café', tone: PopTone.soft, initial: 'C'),
  Payee(name: 'Dad', tone: PopTone.soft, initial: 'D'),
  Payee(name: 'More', tone: PopTone.neutral, initial: '+'),
];
