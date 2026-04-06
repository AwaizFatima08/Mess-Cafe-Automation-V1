import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/add_menu_item_dialog.dart';
import '../widgets/edit_menu_item_dialog.dart';

class MenuManagementScreen extends StatefulWidget {
  final String userEmail;

  const MenuManagementScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _appliedSearchQuery = '';
  String _selectedFoodType = 'All';
  String _selectedMealType = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> loadMenuItems() {
    return FirebaseFirestore.instance.collection('menu_items').snapshots();
  }

  void _applySearch() {
    final value = _searchController.text.trim().toLowerCase();
    if (value == _appliedSearchQuery) return;

    setState(() {
      _appliedSearchQuery = value;
    });
  }

  bool isItemActive(Map<String, dynamic> data) {
    return data['is_active'] == true;
  }

  bool isItemVisible(Map<String, dynamic> data) {
    final raw = data['is_visible'];
    if (raw is bool) return raw;
    return true;
  }

  String formatStatus(Map<String, dynamic> data) {
    return isItemActive(data) ? 'Active' : 'Inactive';
  }

  String getItemName(Map<String, dynamic> data, String docId) {
    final name = (data['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final legacyName = (data['item_name'] ?? '').toString().trim();
    if (legacyName.isNotEmpty) return legacyName;

    return docId;
  }

  String getItemCode(Map<String, dynamic> data, String docId) {
    final itemId = (data['item_Id'] ?? '').toString().trim();
    if (itemId.isNotEmpty) return itemId;
    return docId;
  }

  String getFoodTypeLabel(Map<String, dynamic> data) {
    final foodTypeName = (data['food_type_name'] ?? '').toString().trim();
    if (foodTypeName.isNotEmpty) return foodTypeName;

    final foodTypeCode = (data['food_type_code'] ?? '').toString().trim();
    if (foodTypeCode.isNotEmpty) return foodTypeCode;

    return 'unspecified';
  }

  double getEstimatedPrice(Map<String, dynamic> data) {
    final raw = data['estimated_price'];

    if (raw is num) return raw.toDouble();

    if (raw is String) {
      final cleaned = raw.replaceAll(',', '').trim();
      return double.tryParse(cleaned) ?? 0;
    }

    return 0;
  }

  int getSortOrder(Map<String, dynamic> data) {
    final raw = data['sort_order'];

    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 999999;

    return 999999;
  }

  List<String> getMealTypes(Map<String, dynamic> data) {
    final raw = data['available_meal_types'];

    if (raw is Iterable) {
      return raw
          .map((e) => e.toString().trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    }

    if (raw is String) {
      final normalized = raw
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('“', '')
          .replaceAll('”', '')
          .replaceAll('"', '')
          .replaceAll("'", '');

      return normalized
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    }

    final legacyCategory =
        (data['category'] ?? '').toString().trim().toLowerCase();
    if (legacyCategory.isNotEmpty) {
      return [legacyCategory];
    }

    return const [];
  }

  IconData getItemIcon(List<String> mealTypes, String foodType) {
    final normalizedFoodType = foodType.trim().toLowerCase();

    if (mealTypes.contains('breakfast')) {
      return Icons.free_breakfast_outlined;
    }
    if (mealTypes.contains('lunch')) {
      return Icons.lunch_dining_outlined;
    }
    if (mealTypes.contains('dinner')) {
      return Icons.dinner_dining_outlined;
    }
    if (mealTypes.contains('cafe') ||
        normalizedFoodType == 'beverage' ||
        normalizedFoodType == 'hot_beverage') {
      return Icons.local_drink_outlined;
    }

    return Icons.restaurant_menu;
  }

  Map<String, dynamic> buildEditPayload(
    Map<String, dynamic> data,
    String docId,
  ) {
    final mealTypes = getMealTypes(data);
    final itemName = getItemName(data, docId);

    return {
      ...data,
      'name': itemName,
      'item_Id': getItemCode(data, docId),
      'available_meal_types': mealTypes,
      'food_type_name': (data['food_type_name'] ?? '').toString().trim(),
      'food_type_code': (data['food_type_code'] ?? '').toString().trim(),
      'estimated_price': getEstimatedPrice(data),
      'is_active': isItemActive(data),
      'is_visible': isItemVisible(data),
      'item_name': itemName,
      'category': mealTypes.isNotEmpty ? mealTypes.first : '',
    };
  }

  Future<void> toggleItemActive(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      final nextActive = !isItemActive(data);

      await FirebaseFirestore.instance
          .collection('menu_items')
          .doc(docId)
          .update({
        'is_active': nextActive,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextActive ? 'Menu item activated.' : 'Menu item deactivated.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update menu item: $e'),
        ),
      );
    }
  }

  Color _statusColor(bool active) {
    return active ? Colors.green : Colors.red;
  }

  List<String> _buildFoodTypeOptions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final values = docs
        .map((doc) => getFoodTypeLabel(doc.data()))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ['All', ...values];
  }

  List<String> _buildMealTypeOptions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final values = <String>{};

    for (final doc in docs) {
      values.addAll(getMealTypes(doc.data()));
    }

    final sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ['All', ...sorted];
  }

  bool _matchesFilters(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final itemName = getItemName(data, doc.id).toLowerCase();
    final itemCode = getItemCode(data, doc.id).toLowerCase();
    final foodType = getFoodTypeLabel(data).toLowerCase();
    final mealTypes = getMealTypes(data);

    final matchesSearch = _appliedSearchQuery.isEmpty ||
        itemName.contains(_appliedSearchQuery) ||
        itemCode.contains(_appliedSearchQuery);

    final matchesFoodType = _selectedFoodType == 'All' ||
        foodType == _selectedFoodType.toLowerCase();

    final matchesMealType = _selectedMealType == 'All' ||
        mealTypes.contains(_selectedMealType.toLowerCase());

    return matchesSearch && matchesFoodType && matchesMealType;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _appliedSearchQuery = '';
      _selectedFoodType = 'All';
      _selectedMealType = 'All';
    });
  }

  Widget _buildSearchAndFilters(
    List<String> foodTypeOptions,
    List<String> mealTypeOptions,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applySearch(),
              decoration: InputDecoration(
                hintText: 'Search by item name or item ID',
                prefixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _applySearch,
                  icon: const Icon(Icons.search),
                ),
                suffixIcon: _searchController.text.trim().isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final useVertical = constraints.maxWidth < 700;

                final foodTypeDropdown = DropdownButtonFormField<String>(
                  initialValue: foodTypeOptions.contains(_selectedFoodType)
                      ? _selectedFoodType
                      : 'All',
                  decoration: InputDecoration(
                    labelText: 'Food Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: foodTypeOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedFoodType = value;
                    });
                  },
                );

                final mealTypeDropdown = DropdownButtonFormField<String>(
                  initialValue: mealTypeOptions.contains(_selectedMealType)
                      ? _selectedMealType
                      : 'All',
                  decoration: InputDecoration(
                    labelText: 'Meal Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: mealTypeOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedMealType = value;
                    });
                  },
                );

                final searchButton = SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _applySearch,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                );

                final clearButton = SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Clear'),
                  ),
                );

                if (useVertical) {
                  return Column(
                    children: [
                      foodTypeDropdown,
                      const SizedBox(height: 12),
                      mealTypeDropdown,
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: searchButton),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: clearButton),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: foodTypeDropdown),
                    const SizedBox(width: 12),
                    Expanded(child: mealTypeDropdown),
                    const SizedBox(width: 12),
                    searchButton,
                    const SizedBox(width: 12),
                    clearButton,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const AddMenuItemDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: loadMenuItems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error loading menu items: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
            snapshot.data?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
          )..sort((a, b) {
                  final aData = a.data();
                  final bData = b.data();

                  final sortCompare =
                      getSortOrder(aData).compareTo(getSortOrder(bData));
                  if (sortCompare != 0) return sortCompare;

                  final nameCompare = getItemName(aData, a.id)
                      .toLowerCase()
                      .compareTo(getItemName(bData, b.id).toLowerCase());
                  if (nameCompare != 0) return nameCompare;

                  return a.id.compareTo(b.id);
                });

          final foodTypeOptions = _buildFoodTypeOptions(docs);
          final mealTypeOptions = _buildMealTypeOptions(docs);

          if (!foodTypeOptions.contains(_selectedFoodType)) {
            _selectedFoodType = 'All';
          }
          if (!mealTypeOptions.contains(_selectedMealType)) {
            _selectedMealType = 'All';
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs =
              docs.where(_matchesFilters).toList();

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logged in as: ${widget.userEmail}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Menu Items',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text('Total: ${filteredDocs.length}/${docs.length}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSearchAndFilters(foodTypeOptions, mealTypeOptions),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No menu items found'),
                    ),
                  )
                else if (filteredDocs.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No menu items match current filters'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data();

                        final itemName = getItemName(data, doc.id);
                        final baseUnit = (data['base_unit'] ?? '').toString().trim();
                        final displayName = baseUnit.isNotEmpty
                            ? '$itemName ($baseUnit)'
                            : itemName;
                        final itemCode = getItemCode(data, doc.id);
                        final mealTypes = getMealTypes(data);
                        final foodType = getFoodTypeLabel(data);
                        final estimatedPrice = getEstimatedPrice(data);
                        final active = isItemActive(data);
                        final visible = isItemVisible(data);

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              getItemIcon(mealTypes, foodType),
                            ),
                            title: Text(displayName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'ID: $itemCode • Food Type: $foodType • Rs ${estimatedPrice.toStringAsFixed(0)}',
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    ...mealTypes.map(
                                      (mealType) => Chip(
                                        label: Text(mealType),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        visible ? 'Visible' : 'Hidden',
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  formatStatus(data),
                                  style: TextStyle(
                                    color: _statusColor(active),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => EditMenuItemDialog(
                                        itemId: doc.id,
                                        existingData:
                                            buildEditPayload(data, doc.id),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: active ? 'Deactivate' : 'Activate',
                                  onPressed: () =>
                                      toggleItemActive(context, doc.id, data),
                                  icon: Icon(
                                    active ? Icons.toggle_on : Icons.toggle_off,
                                    color: active ? Colors.green : Colors.grey,
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
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
