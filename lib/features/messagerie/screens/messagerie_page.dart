import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class MessageriePage extends StatefulWidget {
  final bool isStandalone;
  const MessageriePage({super.key, this.isStandalone = false});

  @override
  State<MessageriePage> createState() => _MessageriePageState();
}

class _MessageriePageState extends State<MessageriePage> {
  String _selectedFilter = 'Tous';
  final _searchController = TextEditingController();

  final List<_ConversationData> _conversations = [
    _ConversationData(
      id: '1',
      name: 'Yassine Mejri',
      role: 'Conducteur',
      route: 'Ariana → ESPRIT',
      lastMessage: 'Je serai au point de ramassage à 07h45 précises.',
      time: '08:12',
      unreadCount: 2,
      avatarColor: const Color(0xFF4A90E2),
      isOnline: true,
    ),
    _ConversationData(
      id: '2',
      name: 'Sarra Mansour',
      role: 'Passagère',
      route: 'Tunis Centre → Ghazela',
      lastMessage: 'Super, j\'ai bien réservé ma place pour demain !',
      time: 'Hier',
      unreadCount: 0,
      avatarColor: const Color(0xFFE94E77),
      isOnline: false,
    ),
    _ConversationData(
      id: '3',
      name: 'Ahmed Khemir',
      role: 'Conducteur',
      route: 'Bizerte → Campus El Manar',
      lastMessage: 'Reste-t-il une place pour le retour de 17h ?',
      time: 'Hier',
      unreadCount: 1,
      avatarColor: const Color(0xFF50E3C2),
      isOnline: true,
    ),
    _ConversationData(
      id: '4',
      name: 'Nour Ben Ali',
      role: 'Conductrice',
      route: 'Marsa → ESPRIT',
      lastMessage: 'Merci pour le trajet agréable et ponctuel !',
      time: 'Lun',
      unreadCount: 0,
      avatarColor: const Color(0xFFF5A623),
      isOnline: false,
    ),
    _ConversationData(
      id: '5',
      name: 'Support Covoiturage Étudiant',
      role: 'Assistance',
      route: 'Aide & Sécurité',
      lastMessage: 'Votre compte étudiant a été certifié avec succès.',
      time: 'Dim',
      unreadCount: 0,
      avatarColor: AppColors.primaire,
      isOnline: true,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChatModal(BuildContext context, _ConversationData conv) {
    final msgController = TextEditingController();
    final messages = [
      _ChatMessage(sender: conv.name, text: 'Bonjour ! Tu es disponible pour le covoiturage demain matin ?', isMe: false, time: '08:05'),
      _ChatMessage(sender: 'Moi', text: 'Oui tout à fait, il me reste 2 places disponibles !', isMe: true, time: '08:08'),
      _ChatMessage(sender: conv.name, text: conv.lastMessage, isMe: false, time: conv.time),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.sizeOf(context).height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Header du chat modal
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.bordure)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: conv.avatarColor,
                      child: Text(
                        conv.name[0],
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conv.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: conv.isOnline ? AppColors.accent : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${conv.role} • ${conv.route}',
                                style: const TextStyle(fontSize: 11, color: AppColors.texte2),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.texte2),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),

              // Liste des messages
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, idx) {
                    final msg = messages[idx];
                    return Align(
                      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
                        decoration: BoxDecoration(
                          color: msg.isMe ? AppColors.primaire : AppColors.champFond,
                          borderRadius: BorderRadius.circular(18).copyWith(
                            bottomRight: msg.isMe ? const Radius.circular(2) : const Radius.circular(18),
                            bottomLeft: !msg.isMe ? const Radius.circular(2) : const Radius.circular(18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text,
                              style: TextStyle(
                                color: msg.isMe ? Colors.white : AppColors.texte,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              msg.time,
                              style: TextStyle(
                                color: msg.isMe ? Colors.white70 : AppColors.texte2,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Barre de saisie
              Container(
                padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.paddingOf(context).bottom + 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.bordure)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.champFond,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: msgController,
                          decoration: const InputDecoration(
                            hintText: 'Écrire un message...',
                            hintStyle: TextStyle(fontSize: 13, color: AppColors.texte2),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primaire,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 19),
                        onPressed: () {
                          final text = msgController.text.trim();
                          if (text.isNotEmpty) {
                            setModalState(() {
                              messages.add(_ChatMessage(sender: 'Moi', text: text, isMe: true, time: 'Maintenant'));
                              msgController.clear();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _conversations.where((conv) {
      if (_selectedFilter == 'Conducteurs' && conv.role != 'Conducteur' && conv.role != 'Conductrice') return false;
      if (_selectedFilter == 'Passagers' && conv.role != 'Passager' && conv.role != 'Passagère') return false;
      if (_selectedFilter == 'Non lus' && conv.unreadCount == 0) return false;
      if (_searchController.text.trim().isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        return conv.name.toLowerCase().contains(query) || conv.route.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        title: const Text(
          'Messagerie',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        automaticallyImplyLeading: widget.isStandalone,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.bordure),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: AppColors.texte2, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un covoitureur ou un trajet...',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.texte2),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filtres
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['Tous', 'Conducteurs', 'Passagers', 'Non lus'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    selectedColor: AppColors.primaire,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.texte,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaire : AppColors.bordure,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Liste des conversations
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune conversation trouvée.',
                      style: TextStyle(color: AppColors.texte2),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final conv = filtered[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.bordure),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _openChatModal(context, conv),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Avatar avec badge en ligne
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor: conv.avatarColor,
                                        child: Text(
                                          conv.name[0],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      if (conv.isOnline)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: AppColors.accent,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),

                                  // Détails de la conversation
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              conv.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.5,
                                              ),
                                            ),
                                            Text(
                                              conv.time,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.texte2,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.champFond,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                conv.route,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primaire,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                conv.lastMessage,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: conv.unreadCount > 0 ? AppColors.texte : AppColors.texte2,
                                                  fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            if (conv.unreadCount > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaire,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${conv.unreadCount}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConversationData {
  final String id;
  final String name;
  final String role;
  final String route;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final Color avatarColor;
  final bool isOnline;

  const _ConversationData({
    required this.id,
    required this.name,
    required this.role,
    required this.route,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.avatarColor,
    required this.isOnline,
  });
}

class _ChatMessage {
  final String sender;
  final String text;
  final bool isMe;
  final String time;

  const _ChatMessage({
    required this.sender,
    required this.text,
    required this.isMe,
    required this.time,
  });
}
