import 'package:flutter/material.dart';

import '../services/menu_resolver_service.dart';

class ActiveMenuPreviewScreen extends StatefulWidget {
  final String userEmail;

  const ActiveMenuPreviewScreen({super.key, required this.userEmail});

  @override
  State<ActiveMenuPreviewScreen> createState() =>
      _ActiveMenuPreviewScreenState();
}

class _ActiveMenuPreviewScreenState extends State<ActiveMenuPreviewScreen> {
  final MenuResolverService _resolverService = MenuResolverService();

  DateTime selectedDate = DateTime.now();
  Future<Map<String, dynamic>?>? _menuFuture;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  void _loadMenu() {
    setState(() {
      _menuFuture = _resolverService.getMenuForDate(selectedDate);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
    });
    _loadMenu();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '$day ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Active Menu Preview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text('Logged in as: ${widget.userEmail}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Selected Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_formatDate(selectedDate)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Pick Date'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        selectedDate = DateTime.now();
                      });
                      _loadMenu();
                    },
                    icon: const Icon(Icons.today),
                    label: const Text('Today'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadMenu,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard({
    required String title,
    required List<dynamic> items,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: items.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('No items resolved.'),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...items.map((item) {
                    final data = Map<String, dynamic>.from(item as Map);
                    final itemName =
                        (data['item_name'] ?? data['item_id'] ?? 'Unknown item')
                            .toString();
                    final itemId = (data['item_id'] ?? '').toString();
                    final category = (data['category'] ?? 'other').toString();
                    final estimatedPrice = data['estimated_price'] ?? 0;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restaurant_menu),
                      title: Text(itemName),
                      subtitle: Text(
                        '$itemId • $category • Rs $estimatedPrice',
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 42),
            SizedBox(height: 12),
            Text(
              'No active resolved menu found for the selected date.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Check that an active menu cycle exists and that the selected date falls within its date range.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolvedMenu(Map<String, dynamic> menu) {
    final breakfast = (menu['breakfast'] as List?) ?? const [];
    final lunch1 = (menu['lunch_template_1'] as List?) ?? const [];
    final lunch2 = (menu['lunch_template_2'] as List?) ?? const [];
    final dinner1 = (menu['dinner_template_1'] as List?) ?? const [];
    final dinner2 = (menu['dinner_template_2'] as List?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  'Cycle: ${(menu['cycle_name'] ?? '').toString().isEmpty ? menu['cycle_id'] : menu['cycle_name']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Weekday: ${(menu['weekday'] ?? '').toString()}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildMealCard(title: 'Breakfast', items: breakfast),
        _buildMealCard(title: 'Lunch Template 1', items: lunch1),
        _buildMealCard(title: 'Lunch Template 2', items: lunch2),
        _buildMealCard(title: 'Dinner Template 1', items: dinner1),
        _buildMealCard(title: 'Dinner Template 2', items: dinner2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Menu Preview'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _menuFuture,
          builder: (context, snapshot) {
            return ListView(
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (snapshot.hasError)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load active menu: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (snapshot.data == null)
                  _buildEmptyState()
                else
                  _buildResolvedMenu(snapshot.data!),
              ],
            );
          },
        ),
      ),
    );
  }
}
