
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kWorkshopId = 'gam-main';
const kLime = Color(0xFFB8FF28);
const kBg = Color(0xFF071018);
const kPanel = Color(0xFF101D27);
const kPanel2 = Color(0xFF162833);
const kLine = Color(0xFF29404E);
const kMuted = Color(0xFF91A5B2);

class RuntimeFirebaseConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  static bool get ready =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      senderId.isNotEmpty &&
      projectId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
      );
}

class AppSession {
  AppSession({
    required this.online,
    required this.uid,
    this.firebaseError,
  });

  final bool online;
  final String uid;
  final String? firebaseError;

  static Future<AppSession> boot() async {
    if (!RuntimeFirebaseConfig.ready) {
      return AppSession(online: false, uid: 'demo-client');
    }

    try {
      await Firebase.initializeApp(options: RuntimeFirebaseConfig.options);
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      final uid = auth.currentUser!.uid;
      final db = FirebaseFirestore.instance;

      final member = db
          .collection('workshops')
          .doc(kWorkshopId)
          .collection('members')
          .doc(uid);
      final memberSnap = await member.get();
      if (!memberSnap.exists) {
        await member.set({
          'role': 'client',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await db
          .collection('workshops')
          .doc(kWorkshopId)
          .collection('chats')
          .doc(uid)
          .set({
        'clientUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'open',
      }, SetOptions(merge: true));

      return AppSession(online: true, uid: uid);
    } catch (e) {
      return AppSession(
        online: false,
        uid: 'demo-client',
        firebaseError: e.toString(),
      );
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ru_RU';
  final session = await AppSession.boot();
  runApp(GamApp(session: session));
}

class GamApp extends StatelessWidget {
  const GamApp({super.key, required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: kLime,
      brightness: Brightness.dark,
      surface: kPanel,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GAM',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme.copyWith(
          primary: kLime,
          secondary: kLime,
          surface: kPanel,
        ),
        scaffoldBackgroundColor: kBg,
        cardColor: kPanel,
        dividerColor: kLine,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kPanel2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kLine),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kLine),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kLime, width: 1.4),
          ),
        ),
      ),
      home: GamShell(session: session),
    );
  }
}

class GamShell extends StatefulWidget {
  const GamShell({super.key, required this.session});
  final AppSession session;

  @override
  State<GamShell> createState() => _GamShellState();
}

class _GamShellState extends State<GamShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(session: widget.session, onOpen: (i) => setState(() => index = i)),
      ChatPage(session: widget.session),
      BookingPage(session: widget.session),
      RepairPage(session: widget.session),
      ProfilePage(session: widget.session),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 14,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kLime,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: const Text(
                'GAM',
                style: TextStyle(
                  color: kBg,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Городская автомобильная мастерская',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Всегда на связи',
                    style: TextStyle(fontSize: 11, color: kMuted),
                  ),
                ],
              ),
            ),
            StatusPill(online: widget.session.online),
          ],
        ),
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF09141C),
        indicatorColor: kLime.withValues(alpha: .12),
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: kLime), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble, color: kLime), label: 'Чат'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month, color: kLime), label: 'Запись'),
          NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build, color: kLime), label: 'Ремонт'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: kLime), label: 'Профиль'),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: online ? kLime.withValues(alpha: .12) : Colors.orange.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: online ? kLime.withValues(alpha: .35) : Colors.orange),
      ),
      child: Text(
        online ? 'ОНЛАЙН' : 'ДЕМО',
        style: TextStyle(
          color: online ? kLime : Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.session, required this.onOpen});
  final AppSession session;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF123044), kBg],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kLine),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ваш автомобиль.\nПод контролем.',
                style: TextStyle(fontSize: 29, height: 1.05, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('Чат с мастером, запись, смета и статус ремонта — в одном приложении.',
                style: TextStyle(color: kMuted, height: 1.35)),
            ],
          ),
        ),
        if (!session.online) ...[
          const SizedBox(height: 12),
          GamCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_off, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    session.firebaseError == null
                        ? 'GAM 2.0 работает в демо-режиме. После подключения Firebase чат и записи станут общими для клиентов и автосервиса.'
                        : 'Firebase пока не подключился. Приложение продолжает работать в демо-режиме.',
                    style: const TextStyle(color: kMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.18,
          children: [
            QuickCard(icon: Icons.chat_bubble_outline, title: 'Написать мастеру', subtitle: 'Онлайн-чат', onTap: () => onOpen(1)),
            QuickCard(icon: Icons.calendar_month_outlined, title: 'Записаться', subtitle: 'Дата и услуга', onTap: () => onOpen(2)),
            QuickCard(icon: Icons.build_outlined, title: 'Статус ремонта', subtitle: 'Этапы и смета', onTap: () => onOpen(3)),
            QuickCard(icon: Icons.directions_car_outlined, title: 'Мой автомобиль', subtitle: 'История сервиса', onTap: () => onOpen(4)),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle(title: 'Текущий ремонт'),
        GamCard(
          onTap: () => onOpen(3),
          child: const Row(
            children: [
              CircleAvatar(radius: 23, backgroundColor: Color(0xFF223541), child: Icon(Icons.directions_car, color: kLime)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Toyota Camry', style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('A123BC152 · ремонт подвески', style: TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              ),
              Text('62%', style: TextStyle(color: kLime, fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}

class QuickCard extends StatelessWidget {
  const QuickCard({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GamCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kLime),
          const Spacer(),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: kMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class GamCard extends StatelessWidget {
  const GamCard({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
      ),
      child: child,
    );
    return onTap == null ? card : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: card);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 9),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class ChatMessage {
  ChatMessage({required this.mine, required this.text, required this.time});
  final bool mine;
  final String text;
  final DateTime time;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.session});
  final AppSession session;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();
  final demoMessages = <ChatMessage>[
    ChatMessage(mine: false, text: 'Здравствуйте! Машина принята в работу.', time: DateTime.now().subtract(const Duration(minutes: 22))),
    ChatMessage(mine: true, text: 'Спасибо. Напишите по результатам диагностики.', time: DateTime.now().subtract(const Duration(minutes: 18))),
    ChatMessage(mine: false, text: 'Нашли износ сайлентблоков. Смета добавлена в приложение.', time: DateTime.now().subtract(const Duration(minutes: 12))),
  ];

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();

    if (widget.session.online) {
      final db = FirebaseFirestore.instance;
      final chat = db.collection('workshops').doc(kWorkshopId).collection('chats').doc(widget.session.uid);
      await chat.set({
        'clientUid': widget.session.uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': text,
      }, SetOptions(merge: true));
      await chat.collection('messages').add({
        'senderId': widget.session.uid,
        'senderRole': 'client',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      setState(() {
        demoMessages.add(ChatMessage(mine: true, text: text, time: DateTime.now()));
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (widget.session.online) {
      final stream = FirebaseFirestore.instance
          .collection('workshops').doc(kWorkshopId)
          .collection('chats').doc(widget.session.uid)
          .collection('messages').orderBy('createdAt').snapshots();

      body = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Ошибка чата: ${snap.error}', style: const TextStyle(color: kMuted)));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final messages = snap.data!.docs.map((doc) {
            final d = doc.data();
            final stamp = d['createdAt'];
            final time = stamp is Timestamp ? stamp.toDate() : DateTime.now();
            return ChatMessage(
              mine: d['senderId'] == widget.session.uid,
              text: (d['text'] ?? '').toString(),
              time: time,
            );
          }).toList();
          return MessageList(messages: messages);
        },
      );
    } else {
      body = MessageList(messages: demoMessages);
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(17), border: Border.all(color: kLine)),
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Color(0xFF243743), child: Text('МА', style: TextStyle(fontWeight: FontWeight.w800))),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Мастер Алексей', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text('Диагностика и ремонт', style: TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              ),
              StatusPill(online: widget.session.online),
            ],
          ),
        ),
        Expanded(child: body),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => send(),
                    decoration: const InputDecoration(hintText: 'Сообщение мастеру...', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: send,
                  style: IconButton.styleFrom(backgroundColor: kLime, foregroundColor: kBg),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MessageList extends StatelessWidget {
  const MessageList({super.key, required this.messages});
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        return Align(
          alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 310),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
            decoration: BoxDecoration(
              color: m.mine ? kLime : kPanel2,
              borderRadius: BorderRadius.circular(16),
              border: m.mine ? null : Border.all(color: kLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(m.text, style: TextStyle(color: m.mine ? kBg : Colors.white, height: 1.3)),
                const SizedBox(height: 4),
                Text(DateFormat('HH:mm').format(m.time),
                  style: TextStyle(color: m.mine ? kBg.withValues(alpha: .55) : kMuted, fontSize: 10)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BookingPage extends StatefulWidget {
  const BookingPage({super.key, required this.session});
  final AppSession session;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final services = const [
    ('Замена масла', Icons.oil_barrel_outlined),
    ('Диагностика', Icons.search),
    ('Шиномонтаж', Icons.tire_repair_outlined),
    ('Подвеска', Icons.car_repair_outlined),
  ];
  final times = const ['09:00', '10:00', '11:00', '13:00', '15:00', '17:00'];
  String service = 'Замена масла';
  String time = '09:00';
  DateTime date = DateTime.now().add(const Duration(days: 1));
  bool saving = false;

  Future<void> save() async {
    setState(() => saving = true);
    try {
      if (widget.session.online) {
        await FirebaseFirestore.instance.collection('workshops').doc(kWorkshopId).collection('bookings').add({
          'clientUid': widget.session.uid,
          'service': service,
          'date': DateFormat('yyyy-MM-dd').format(date),
          'time': time,
          'status': 'new',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_booking', '${DateFormat('dd.MM.yyyy').format(date)}|$time|$service');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.session.online ? 'Запись отправлена в автосервис' : 'Запись сохранена в демо-режиме')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        const SectionTitle(title: 'Запись на сервис'),
        GamCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Выберите услугу', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: services.map((s) {
                  final selected = s.$1 == service;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(s.$1),
                    avatar: Icon(s.$2, size: 18, color: selected ? kBg : Colors.white),
                    selectedColor: kLime,
                    labelStyle: TextStyle(color: selected ? kBg : Colors.white, fontWeight: FontWeight.w700),
                    onSelected: (_) => setState(() => service = s.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: kLime),
                title: const Text('Дата'),
                subtitle: Text(DateFormat('dd.MM.yyyy').format(date)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                    initialDate: date,
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
              const SizedBox(height: 8),
              const Text('Время', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: times.map((t) {
                  final selected = t == time;
                  return ChoiceChip(
                    selected: selected,
                    selectedColor: kLime,
                    labelStyle: TextStyle(color: selected ? kBg : Colors.white, fontWeight: FontWeight.w700),
                    label: Text(t),
                    onSelected: (_) => setState(() => time = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : save,
                  style: FilledButton.styleFrom(backgroundColor: kLime, foregroundColor: kBg, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(saving ? 'Сохраняю...' : 'Записаться'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RepairPage extends StatelessWidget {
  const RepairPage({super.key, required this.session});
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    if (!session.online) {
      return RepairDetails(
        session: session,
        data: const {
          'car': 'Toyota Camry',
          'plate': 'A123BC152',
          'order': '4587',
          'stage': 3,
          'workPrice': 14500,
          'partsPrice': 10000,
        },
      );
    }

    final ref = FirebaseFirestore.instance.collection('workshops').doc(kWorkshopId).collection('repairs').doc(session.uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Ошибка статуса: ${snap.error}', style: const TextStyle(color: kMuted)));
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (!snap.data!.exists) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Активного ремонта пока нет. Когда мастер создаст заказ-наряд, статус появится здесь.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kMuted),
              ),
            ),
          );
        }
        return RepairDetails(session: session, data: snap.data!.data()!);
      },
    );
  }
}

class RepairDetails extends StatelessWidget {
  const RepairDetails({super.key, required this.session, required this.data});
  final AppSession session;
  final Map<String, dynamic> data;

  Future<void> approve(BuildContext context) async {
    if (session.online) {
      await FirebaseFirestore.instance
          .collection('workshops').doc(kWorkshopId)
          .collection('repairs').doc(session.uid)
          .collection('approvals').doc(session.uid)
          .set({
        'clientUid': session.uid,
        'approved': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('estimate_approved', true);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Смета согласована')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = (data['stage'] as num?)?.toInt() ?? 3;
    final work = (data['workPrice'] as num?)?.toInt() ?? 0;
    final parts = (data['partsPrice'] as num?)?.toInt() ?? 0;
    final total = work + parts;
    final stages = const [
      ('Принят в работу', 'Автомобиль на посту'),
      ('Диагностика', 'Проверка неисправностей'),
      ('Согласование сметы', 'Стоимость работ и запчастей'),
      ('Ремонт', 'Выполняются работы'),
      ('Финальная проверка', 'Контроль и выдача'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        GamCard(
          child: Row(
            children: [
              const CircleAvatar(radius: 23, backgroundColor: Color(0xFF223541), child: Icon(Icons.directions_car, color: kLime)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((data['car'] ?? 'Автомобиль').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${data['plate'] ?? ''} · Заказ-наряд №${data['order'] ?? '—'}',
                      style: const TextStyle(color: kMuted, fontSize: 12)),
                  ],
                ),
              ),
              const StatusPill(online: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GamCard(
          child: Column(
            children: List.generate(stages.length, (i) {
              final done = i < stage;
              final now = i == stage;
              return Padding(
                padding: EdgeInsets.only(bottom: i == stages.length - 1 ? 0 : 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? kLime : Colors.transparent,
                        border: Border.all(color: done || now ? kLime : kLine, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: done
                          ? const Icon(Icons.check, color: kBg, size: 18)
                          : Text('${i + 1}', style: TextStyle(color: now ? kLime : kMuted, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stages[i].$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(stages[i].$2, style: const TextStyle(color: kMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        GamCard(
          child: Column(
            children: [
              PriceRow(label: 'Работы', value: work),
              PriceRow(label: 'Запчасти', value: parts),
              const Divider(),
              PriceRow(label: 'Итого', value: total, total: true),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => approve(context),
                  style: FilledButton.styleFrom(backgroundColor: kLime, foregroundColor: kBg, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Согласовать смету'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PriceRow extends StatelessWidget {
  const PriceRow({super.key, required this.label, required this.value, this.total = false});
  final String label;
  final int value;
  final bool total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: total ? FontWeight.w900 : FontWeight.w500))),
          Text(
            '${NumberFormat.decimalPattern('ru_RU').format(value)} ₽',
            style: TextStyle(color: total ? kLime : Colors.white, fontWeight: FontWeight.w900, fontSize: total ? 21 : 15),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.session});
  final AppSession session;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final car = TextEditingController();
  final plate = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    name.text = p.getString('name') ?? 'Алексей Иванов';
    phone.text = p.getString('phone') ?? '+7 900 000-00-00';
    car.text = p.getString('car') ?? 'Toyota Camry';
    plate.text = p.getString('plate') ?? 'A123BC152';
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setString('name', name.text.trim()),
      p.setString('phone', phone.text.trim()),
      p.setString('car', car.text.trim()),
      p.setString('plate', plate.text.trim()),
    ]);

    if (widget.session.online) {
      await FirebaseFirestore.instance.collection('users').doc(widget.session.uid).set({
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'car': car.text.trim(),
        'plate': plate.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Профиль сохранён')));
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    car.dispose();
    plate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final shortId = widget.session.uid.substring(0, widget.session.uid.length > 8 ? 8 : widget.session.uid.length);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
      children: [
        GamCard(
          child: Column(
            children: [
              const CircleAvatar(radius: 34, backgroundColor: kLime, child: Icon(Icons.person, color: kBg, size: 36)),
              const SizedBox(height: 12),
              Text(name.text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                widget.session.online ? 'Клиент GAM · ID $shortId' : 'Клиент GAM · демо-профиль',
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GamCard(
          child: Column(
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Имя', prefixIcon: Icon(Icons.person_outline))),
              const SizedBox(height: 10),
              TextField(controller: phone, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Телефон', prefixIcon: Icon(Icons.phone_outlined))),
              const SizedBox(height: 10),
              TextField(controller: car, decoration: const InputDecoration(labelText: 'Автомобиль', prefixIcon: Icon(Icons.directions_car_outlined))),
              const SizedBox(height: 10),
              TextField(controller: plate, decoration: const InputDecoration(labelText: 'Госномер', prefixIcon: Icon(Icons.pin_outlined))),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: save,
                  style: FilledButton.styleFrom(backgroundColor: kLime, foregroundColor: kBg, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Сохранить профиль'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GamCard(
          child: Row(
            children: [
              Icon(widget.session.online ? Icons.cloud_done : Icons.cloud_off, color: widget.session.online ? kLime : Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.session.online
                      ? 'Онлайн-синхронизация Firebase подключена.'
                      : 'Сейчас демо-режим. Для общего чата и записей нужно подключить Firebase-проект.',
                  style: const TextStyle(color: kMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
