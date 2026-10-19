import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../data/challenge_dao.dart';
import '../models/challenge_models.dart';

/// CH-02 : classement d'un defi (seuls les participants apparaissent).
class LeaderboardScreen extends StatefulWidget {
  final Challenge challenge;
  const LeaderboardScreen({super.key, required this.challenge});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderEntry>? _entries;

  @override
  void initState() {
    super.initState();
    ChallengeDao.leaderboard(widget.challenge).then((l) {
      if (mounted) setState(() => _entries = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final list = _entries;
    return Scaffold(
      appBar: AppBar(title: Text('🏆 ${c.title}')),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? const Center(child: Text('Personne n’a encore rejoint ce défi.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final e = list[i];
                    final me = e.userId == Session.userId;
                    const medals = ['🥇', '🥈', '🥉'];
                    return Card(
                      child: ListTile(
                        leading: Text(i < 3 ? medals[i] : '${i + 1}',
                            style: const TextStyle(fontSize: 22)),
                        title: Text(me ? '${e.name} (vous)' : e.name,
                            style: TextStyle(fontWeight: me ? FontWeight.bold : null)),
                        trailing: Text('${e.value.toStringAsFixed(1)} ${c.measureLabel}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: AppColors.gold)),
                      ),
                    );
                  },
                ),
    );
  }
}
