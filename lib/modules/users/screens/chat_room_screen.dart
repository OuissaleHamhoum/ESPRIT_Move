import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/guest_gate.dart';
import '../data/chat_dao.dart';
import '../models/chat_models.dart';

/// CHAT-02 : conversation d'un salon (envoyer / recevoir des messages).
/// Bulle rouge = mes messages, bulle grise = ceux des autres.
class ChatRoomScreen extends StatefulWidget {
  final ChatRoom room;
  const ChatRoomScreen({super.key, required this.room});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final m = await ChatDao.messages(widget.room.id);
    if (!mounted) return;
    setState(() => _messages = m);
    // descend en bas de la liste apres l'affichage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (!await GuestGate.check(context, message: 'Créez un compte pour écrire.')) return;

    final uid = Session.userId!;
    _input.clear();
    await ChatDao.send(widget.room.id, uid, text);
    await _load();

    // Prototype : un autre etudiant repond apres 1 seconde
    await Future.delayed(const Duration(seconds: 1));
    await ChatDao.simulateReply(widget.room.id, uid);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.userId;
    return Scaffold(
      appBar: AppBar(title: Text(widget.room.name)),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const EmptyState(emoji: '💬', message: 'Aucun message. Dites bonjour !')
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final mine = m.userId == me;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: mine ? AppColors.red : Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!mine)
                                Text(m.author,
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.grey)),
                              Text(m.text,
                                  style: TextStyle(color: mine ? Colors.white : null)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(hintText: 'Écrire un message'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.red),
                  onPressed: _send,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
