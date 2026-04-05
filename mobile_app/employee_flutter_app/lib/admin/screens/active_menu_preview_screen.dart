import 'package:flutter/material.dart';

import '../services/menu_resolver_service.dart';

class ActiveMenuPreviewScreen extends StatefulWidget {
  final String userEmail;

  const ActiveMenuPreviewScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<ActiveMenuPreviewScreen> createState() => _ActiveMenuPreviewScreenState();
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

  String _formatLabel(String value) {
    return value
        .split('_')
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  IconData _getMealIcon(String mealType) {
    switch (mealType.trim().toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast_outlined;
      case 'lunch':
        return Icons.lunch_dining_outlined;
      case 'dinner':
        return Icons.dinner_dining_outlined;
      default:
        return Icons.restaurant_menu;
    }
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Check that an active menu cycle exists, the selected date falls within the cycle range, and active weekly template rows exist for that weekday.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _normalizeItemList(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _extractOptionList(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _resolveMealOptions(
    Map<String, dynamic> menu,
    String mealType,
  ) {
    final normalizedKey = '${mealType}_options';
    final normalizedRaw = menu[normalizedKey];

    if (normalizedRaw is List && normalizedRaw.isNotEmpty) {
      final normalizedOptions = _extractOptionList(normalizedRaw);
      if (normalizedOptions.isNotEmpty) {
        return normalizedOptions;
      }
    }

    final legacySingle = menu[mealType];
    if (legacySingle is List) {
      return [
        {
          'option_key': 'default',
          'option_label': 'Default Option',
          'items': _normalizeItemList(legacySingle),
        }
      ];
    }

    final List<Map<String, dynamic>> fallback = [];

    for (var i = 1; i <= 5; i++) {
      final key = '${mealType}_template_$i';
      final raw = menu[key];
      if (raw is List) {
        fallback.add({
          'option_key': 'template_$i',
          'option_label': 'Template $i',
          'items': _normalizeItemList(raw),
        });
      }
    }

    return fallback;
  }

  Widget _buildResolvedItemRow(Map<String, dynamic> item) {
    final itemName = (item['item_name'] ?? item['name'] ?? 'Unknown item')
        .toString()
        .trim();
    final itemId = (item['item_id'] ?? item['item_Id'] ?? '').toString().trim();
    final mealType =
        (item['meal_type'] ?? item['category'] ?? '').toString().trim();
    final foodType = (item['food_type'] ??
            item['food_type_name'] ??
            item['food_type_code'] ??
            '')
        .toString()
        .trim();
    final estimatedPrice = item['estimated_price'];

    String priceText = '0';
    if (estimatedPrice is num) {
      priceText = estimatedPrice.toStringAsFixed(0);
    } else if (estimatedPrice != null) {
      priceText = estimatedPrice.toString();
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.restaurant_menu),
      title: Text(itemName),
      subtitle: Text(
        [
          if (itemId.isNotEmpty) itemId,
          if (mealType.isNotEmpty) mealType,
          if (foodType.isNotEmpty) foodType,
          'Rs $priceText',
        ].join(' • '),
      ),
    );
  }

  Widget _buildMealOptionCard({
    required String mealType,
    required Map<String, dynamic> option,
  }) {
    final optionKey = (option['option_key'] ?? 'default').toString().trim();
    final optionLabel = (option['option_label'] ?? optionKey).toString().trim();
    final items = _normalizeItemList(option['items']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: items.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getMealIcon(mealType)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_formatLabel(mealType)} — ${optionLabel.isEmpty ? _formatLabel(optionKey) : optionLabel}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('No items resolved.'),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getMealIcon(mealType)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_formatLabel(mealType)} — ${optionLabel.isEmpty ? _formatLabel(optionKey) : optionLabel}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Option Key: $optionKey',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  ...items.map(_buildResolvedItemRow),
                ],
              ),
      ),
    );
  }

  Widget _buildMealSection({
    required String mealType,
    required List<Map<String, dynamic>> options,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatLabel(mealType),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (options.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No resolved options found for ${_formatLabel(mealType)}.',
              ),
            ),
          )
        else
          ...options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMealOptionCard(
                mealType: mealType,
                option: option,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> menu) {
    final cycleName = (menu['cycle_name'] ?? '').toString().trim();
    final cycleId = (menu['cycle_id'] ?? '').toString().trim();
    final weekday = (menu['weekday'] ?? '').toString().trim();

    final cycleText = cycleName.isNotEmpty
        ? cycleName
        : (cycleId.isNotEmpty ? cycleId : '(Unnamed Cycle)');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              'Cycle: $cycleText',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (cycleId.isNotEmpty) Text('Cycle ID: $cycleId'),
            if (weekday.isNotEmpty) Text('Weekday: ${_formatLabel(weekday)}'),
            Text('Preview Date: ${_formatDate(selectedDate)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildResolvedMenu(Map<String, dynamic> menu) {
    final breakfastOptions = _resolveMealOptions(menu, 'breakfast');
    final lunchOptions = _resolveMealOptions(menu, 'lunch');
    final dinnerOptions = _resolveMealOptions(menu, 'dinner');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCard(menu),
        const SizedBox(height: 12),
        _buildMealSection(
          mealType: 'breakfast',
          options: breakfastOptions,
        ),
        const SizedBox(height: 12),
        _buildMealSection(
          mealType: 'lunch',
          options: lunchOptions,
        ),
        const SizedBox(height: 12),
        _buildMealSection(
          mealType: 'dinner',
          options: dinnerOptions,
        ),
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
