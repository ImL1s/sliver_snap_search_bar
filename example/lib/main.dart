import 'package:flutter/material.dart';
import 'package:sliver_snap_search_bar/sliver_snap_search_bar.dart';

void main() {
  runApp(const _Example());
}

class _Example extends StatelessWidget {
  const _Example();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sliver_snap_search_bar example',
      theme: ThemeData(useMaterial3: true),
      home: const ChatListPage(),
    );
  }
}

/// Demonstrates the batteries-included [SliverSnapView].
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _textCtrl = TextEditingController();
  final _focus = FocusNode();
  bool _isSearching = false;

  static const _demoNames = <String>[
    'Alice',
    'Bob',
    'Carol',
    'Dan',
    'Erin',
    'Frank',
    'Grace',
    'Hank',
    'Ivy',
    'Jake',
    'Kate',
    'Leo',
    'Mia',
    'Nate',
    'Olive',
    'Paul',
    'Quinn',
    'Ruth',
    'Sam',
    'Tara',
    'Uma',
    'Vic',
    'Will',
    'Xena',
    'Yara',
    'Zack',
    'Amy',
    'Ben',
    'Cleo',
    'Drew',
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _enter() => setState(() => _isSearching = true);

  void _exit() {
    _textCtrl.clear();
    _focus.unfocus();
    setState(() => _isSearching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Chats'),
      ),
      body: SliverSnapView(
        isSearching: _isSearching,
        backgroundColor: Colors.white,
        searchBar: DefaultSliverSnapRow(
          isSearching: _isSearching,
          controller: _textCtrl,
          focusNode: _focus,
          onTap: _enter,
          onBack: _exit,
        ),
        slivers: [
          const SliverToBoxAdapter(child: Divider(height: 1)),
          SliverList.builder(
            itemCount: _demoNames.length,
            itemBuilder: (context, i) {
              final name = _demoNames[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Colors.primaries[i % Colors.primaries.length].shade200,
                  child: Text(name[0]),
                ),
                title: Text(name),
                subtitle: const Text('hey, long time no see'),
                trailing: const Text('09:41'),
              );
            },
          ),
        ],
        searchResultSliver: _isSearching
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    _textCtrl.text.isEmpty
                        ? 'Type to search…'
                        : 'Results for "${_textCtrl.text}"',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
