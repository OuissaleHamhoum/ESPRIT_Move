import 'package:flutter/material.dart';
import '../data/chat_dao.dart';
import '../models/chat_models.dart';
import 'chat_room_screen.dart';

/// CHAT-01 : liste des salons de discussion.
class ChatRoomsScreen extends StatefulWidget {
  const ChatRoomsScreen({super.key});

  @override
  State<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen> {
  List<ChatRoom> _rooms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ChatDao.rooms();
    if (mounted) setState(() => _rooms = r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final r in _rooms)
            Card(
              child: ListTile(
                leading: Text(r.icon, style: const TextStyle(fontSize: 26)),
                title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(r.lastMessage.isEmpty ? 'Aucun message' : r.lastMessage,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ChatRoomScreen(room: r)));
                  _load(); // met a jour l'apercu du dernier message
                },
              ),
            ),
        ],
      ),
    );
  }
}
