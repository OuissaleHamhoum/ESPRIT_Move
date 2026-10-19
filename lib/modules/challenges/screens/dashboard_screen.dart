import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/home_dao.dart';

/// DASH-01 : tableau de bord d'engagement (admin). Calcule depuis SQLite.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<List<Object>> _rows = [];

  @override
  void initState() {
    super.initState();
    HomeDao.dashboard().then((r) {
      if (mounted) setState(() => _rows = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📊 Engagement campus')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final r in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r[0] as String)),
                  Text('${((r[1] as double) * 100).round()} %',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: r[1] as double,
                  color: AppColors.red,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
