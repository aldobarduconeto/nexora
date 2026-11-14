import 'package:flutter/foundation.dart';
import 'package:nexora/src/models/conversation.dart';

class ConversationTab {
  ConversationTab({
    required this.id,
    required this.title,
    this.conversation,
    this.isHome = false,
    this.unreadCount = 0,
    this.hasActiveCall = false,
  });

  final String id;
  String title;
  Conversation? conversation;
  final bool isHome;
  int unreadCount;
  bool hasActiveCall;

  bool get isSavedMessages => conversation?.isSavedMessages ?? false;
  bool get isGroup => conversation?.isGroup ?? false;
  bool get isCommunity => conversation?.isCommunity ?? false;
}

class ConversationTabsService extends ChangeNotifier {
  ConversationTabsService._() {
    _tabs.add(
      ConversationTab(
        id: homeTabId,
        title: 'Início',
        isHome: true,
      ),
    );
  }

  static final ConversationTabsService instance = ConversationTabsService._();
  static const String homeTabId = '__home__';

  final List<ConversationTab> _tabs = [];
  int _activeIndex = 0;

  List<ConversationTab> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;
  ConversationTab get activeTab => _tabs[_activeIndex];

  bool get isHomeActive => _tabs[_activeIndex].isHome;

  void openHome() {
    _activeIndex = 0;
    notifyListeners();
  }

  void selectTabByIndex(int index) {
    if (index >= 0 && index < _tabs.length) {
      _activeIndex = index;
      _tabs[index].unreadCount = 0;
      notifyListeners();
    }
  }

  void selectTabById(String id) {
    final idx = _tabs.indexWhere((t) => t.id == id);
    if (idx != -1) {
      selectTabByIndex(idx);
    }
  }

  void openConversation(Conversation conversation, {String? title}) {
    final convTitle = title ??
        (conversation.isSavedMessages
            ? 'Mensagens Salvas'
            : (conversation.title.isNotEmpty
                ? conversation.title
                : 'Conversa'));

    final existingIndex = _tabs.indexWhere((t) => t.id == conversation.id);
    if (existingIndex != -1) {
      _tabs[existingIndex].conversation = conversation;
      _tabs[existingIndex].title = convTitle;
      _tabs[existingIndex].unreadCount = 0;
      _activeIndex = existingIndex;
    } else {
      final newTab = ConversationTab(
        id: conversation.id,
        title: convTitle,
        conversation: conversation,
        isHome: false,
      );
      _tabs.add(newTab);
      _activeIndex = _tabs.length - 1;
    }
    notifyListeners();
  }

  void closeTab(String id) {
    if (id == homeTabId) return; // Cannot close home tab
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final wasActive = _activeIndex == index;
    _tabs.removeAt(index);

    if (wasActive) {
      if (index < _tabs.length) {
        _activeIndex = index;
      } else {
        _activeIndex = _tabs.length - 1;
      }
    } else if (_activeIndex > index) {
      _activeIndex--;
    }

    notifyListeners();
  }

  void closeOtherTabs(String id) {
    _tabs.removeWhere((t) => !t.isHome && t.id != id);
    _activeIndex = _tabs.indexWhere((t) => t.id == id);
    if (_activeIndex == -1) _activeIndex = 0;
    notifyListeners();
  }

  void closeAllConversationTabs() {
    _tabs.removeWhere((t) => !t.isHome);
    _activeIndex = 0;
    notifyListeners();
  }

  void setTabCallState(String conversationId, bool hasCall) {
    final idx = _tabs.indexWhere((t) => t.id == conversationId);
    if (idx != -1 && _tabs[idx].hasActiveCall != hasCall) {
      _tabs[idx].hasActiveCall = hasCall;
      notifyListeners();
    }
  }

  void setTabUnread(String conversationId, int count) {
    final idx = _tabs.indexWhere((t) => t.id == conversationId);
    if (idx != -1 && idx != _activeIndex) {
      _tabs[idx].unreadCount = count;
      notifyListeners();
    }
  }

  void incrementTabUnread(String conversationId) {
    final idx = _tabs.indexWhere((t) => t.id == conversationId);
    if (idx != -1 && idx != _activeIndex) {
      _tabs[idx].unreadCount++;
      notifyListeners();
    }
  }

  ConversationTab? getTabWithActiveCall() {
    try {
      return _tabs.firstWhere((t) => t.hasActiveCall && !t.isHome);
    } catch (_) {
      return null;
    }
  }
}
