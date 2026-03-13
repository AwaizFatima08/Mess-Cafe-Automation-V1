import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MessCafeApp());
}

class MessCafeApp extends StatelessWidget {
  const MessCafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mess & Cafe Automation V1',
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController(text: 'testmanager@ffc.local');
  final passwordController = TextEditingController(text: 'Test@12345');

  String message = 'Sign in to continue';

  Future<void> login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() {
        message = 'Login error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess & Cafe Automation V1'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: login,
                child: const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<List<Map<String, dynamic>>> loadBreakfastMenu() async {
    final dailyMenuDoc = await FirebaseFirestore.instance
        .collection('daily_menus')
        .doc('2026-03-15')
        .get();

    final dailyMenuData = dailyMenuDoc.data();
    if (dailyMenuData == null) return [];

    final breakfastItemIds =
        List<String>.from(dailyMenuData['breakfast_items'] ?? []);

    final List<Map<String, dynamic>> breakfastItems = [];

    for (final itemId in breakfastItemIds) {
      final itemDoc = await FirebaseFirestore.instance
          .collection('menu_items')
          .doc(itemId)
          .get();

      final itemData = itemDoc.data();
      if (itemData != null) {
        breakfastItems.add({
          'id': itemId,
          'name': itemData['name'] ?? itemId,
          'category': itemData['category'] ?? '',
          'veg': itemData['veg'] ?? false,
        });
      }
    }

    return breakfastItems;
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today Menu'),
        actions: [
          IconButton(
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: loadBreakfastMenu(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error loading menu: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final breakfastItems = snapshot.data ?? [];

          if (breakfastItems.isEmpty) {
            return const Center(
              child: Text('No breakfast menu found for 2026-03-15'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logged in as: ${user?.email ?? "Unknown"}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Breakfast Menu',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...breakfastItems.map(
                  (item) => Card(
                    child: ListTile(
                      title: Text(item['name']),
                      subtitle: Text('ID: ${item['id']}'),
                      trailing: Icon(
                        item['veg'] == true
                            ? Icons.eco
                            : Icons.restaurant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
