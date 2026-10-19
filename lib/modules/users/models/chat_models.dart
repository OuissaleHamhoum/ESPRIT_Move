/// Salon de discussion (table "rooms") + apercu du dernier message.
class ChatRoom {
  final int id;
  final String name;
  final String icon;
  final String lastMessage; // vide s'il n'y a aucun message
  const ChatRoom(this.id, this.name, this.icon, this.lastMessage);
}

/// Message (table "messages") avec le nom de son auteur.
class ChatMessage {
  final int id;
  final int userId;
  final String author;
  final String text;
  const ChatMessage(this.id, this.userId, this.author, this.text);
}
