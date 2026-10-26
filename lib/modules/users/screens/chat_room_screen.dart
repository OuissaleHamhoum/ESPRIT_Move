import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/guest_gate.dart';
import '../data/chat_dao.dart';
import '../models/chat_models.dart';

/// CHAT-02 : conversation d'un salon (envoyer / recevoir des messages).
/// Bulle rouge = mes messages, bulle grise = ceux des autres.
/// Les nouveaux messages (autres comptes sur la meme base) arrivent
/// automatiquement : on verifie toutes les 3 secondes.
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
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refreshIfNew());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final m = await ChatDao.messages(widget.room.id);
    if (!mounted) return;
    setState(() {
      _messages = m;
      _loading = false;
    });
    // descend en bas de la liste apres l'affichage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// Recharge seulement s'il y a un message plus recent que le dernier affiche.
  Future<void> _refreshIfNew() async {
    final last = await ChatDao.lastId(widget.room.id);
    final shown = _messages.isEmpty ? 0 : _messages.last.id;
    if (last != shown) _load();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    if (!await GuestGate.check(context, message: 'Créez un compte pour écrire.')) return;

    setState(() => _sending = true);
    try {
      await ChatDao.send(widget.room.id, Session.userId!, text);
      _input.clear();
      await _load();
    } catch (_) {
      if (mounted) AppSnack.show(context, 'Message non envoyé, réessayez.', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.userId;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.room.icon}  ${widget.room.name}')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const EmptyState(emoji: '💬', message: 'Aucun message. Dites bonjour !')
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _bubble(_messages[i], _messages[i].userId == me),
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(hintText: 'Écrire un message'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.red),
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m, bool mine) {
    final time = '${Fmt.two(m.sentAt.hour)}:${Fmt.two(m.sentAt.minute)}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: mine ? AppColors.red : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(m.author, style: const TextStyle(fontSize: 11, color: AppColors.grey)),
            Text(m.text, style: TextStyle(color: mine ? Colors.white : null)),
            const SizedBox(height: 2),
            Text(time,
                style: TextStyle(
                    fontSize: 10, color: mine ? Colors.white70 : AppColors.grey)),
          ],
        ),
      ),
    );
  }
}
