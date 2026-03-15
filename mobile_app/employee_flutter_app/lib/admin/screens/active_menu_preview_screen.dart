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

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
      _loadMenu();
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final monthNames = const [
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
    final month = monthNames[date.month - 1];
    return '$day $month ${date.year}';
  }

  String _formatLabel(String value) {
    return value
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Active Menu Preview',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Logged in as: ${widget.userEmail}',
              style: const TextStyle(fontSize: 14),
            ),
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

  Widget _buildCycleSummary(Map<String, dynamic> menu) {
    final cycleName = (menu['cycle_name'] ?? '').toString();
    final weekday = (menu['weekday'] ?? '').toString();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.restaurant_menu, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cycleName.isEmpty ? 'Unnamed Cycle' : cycleName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Weekday: ${_formatLabel(weekday)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection({
    required String title,
    required List<dynamic> items,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text(
                'No items configured.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...items.map((item) {
                final data = Map<String, dynamic>.from(item as Map);
                final name = (data['name'] ?? data['item_id'] ?? 'Unnamed Item')
                    .toString();
                final price = data['estimated_price'];
                final itemMode = (data['item_mode'] ?? 'inclusive').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.blueGrey.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.fastfood, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: itemMode == 'optional'
                                        ? Colors.orange.withValues(alpha: 0.12)
                                        : Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _formatLabel(itemMode),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: itemMode == 'optional'
                                          ? Colors.orange.shade800
                                          : Colors.green.shade800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Rs ${price ?? 0}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
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
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildResolvedMenu(Map<String, dynamic> menu) {
    final breakfast = List<dynamic>.from(menu['breakfast'] ?? []);
    final lunch1 = List<dynamic>.from(menu['lunch_combo_1'] ?? []);
    final lunch2 = List<dynamic>.from(menu['lunch_combo_2'] ?? []);
    final dinner1 = List<dynamic>.from(menu['dinner_combo_1'] ?? []);
    final dinner2 = List<dynamic>.from(menu['dinner_combo_2'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 12),
        _buildCycleSummary(menu),
        const SizedBox(height: 12),
        _buildMealSection(title: 'Breakfast', items: breakfast),
        _buildMealSection(title: 'Lunch Combo 1', items: lunch1),
        _buildMealSection(title: 'Lunch Combo 2', items: lunch2),
        _buildMealSection(title: 'Dinner Combo 1', items: dinner1),
        _buildMealSection(title: 'Dinner Combo 2', items: dinner2),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildNoMenuFound() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 36, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'No active resolved menu found for the selected date.',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _menuFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Active Menu Preview')),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Active Menu Preview')),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Error loading resolved menu: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final menu = snapshot.data;

        return Scaffold(
          appBar: AppBar(title: const Text('Active Menu Preview')),
          body: menu == null ? _buildNoMenuFound() : _buildResolvedMenu(menu),
        );
      },
    );
  }
}
