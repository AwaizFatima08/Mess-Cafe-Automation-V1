import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/meal_rate_service.dart';

class MealRateManagementScreen extends StatefulWidget {
  const MealRateManagementScreen({super.key});

  @override
  State<MealRateManagementScreen> createState() => _MealRateManagementScreenState();
}

class _MealRateManagementScreenState extends State<MealRateManagementScreen> {
  final MealRateService _rateService = MealRateService();
  DateTime _selectedDate = DateTime.now();
  String _selectedMealType = 'lunch';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rate Management'),
          bottom: TabBar(
            onTap: (index) {
              setState(() {
                _selectedMealType = index == 0 ? 'breakfast' : index == 1 ? 'lunch' : 'dinner';
              });
            },
            tabs: const [Tab(text: 'Breakfast'), Tab(text: 'Lunch'), Tab(text: 'Dinner')],
          ),
          actions: [IconButton(icon: const Icon(Icons.calendar_today), onPressed: _selectDate)],
        ),
        body: _buildRateEntryList(),
      ),
    );
  }

  Widget _buildRateEntryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('menu_items').where('is_active', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final item = docs[index];
            return _RateEntryTile(
              itemId: item.id,
              itemName: item['name'] ?? 'Unknown',
              basePrice: (item['base_price'] ?? 0.0).toDouble(),
              selectedDate: _selectedDate,
              mealType: _selectedMealType,
              rateService: _rateService,
            );
          },
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2100));
    if (picked != null) setState(() => _selectedDate = picked);
  }
}

class _RateEntryTile extends StatefulWidget {
  final String itemId;
  final String itemName;
  final double basePrice;
  final DateTime selectedDate;
  final String mealType;
  final MealRateService rateService;

  const _RateEntryTile({required this.itemId, required this.itemName, required this.basePrice, required this.selectedDate, required this.mealType, required this.rateService});

  @override
  State<_RateEntryTile> createState() => _RateEntryTileState();
}

class _RateEntryTileState extends State<_RateEntryTile> {
  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveRate() async {
    final newRate = double.tryParse(_controller.text);
    if (newRate == null) return;
    setState(() => _isSaving = true);
    try {
      await widget.rateService.updateMealRate(
        menuItemId: widget.itemId,
        date: widget.selectedDate,
        mealType: widget.mealType,
        newRate: newRate,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rate updated")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error saving rate")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(widget.itemName),
        subtitle: Text("Base: Rs. ${widget.basePrice}"),
        trailing: SizedBox(
          width: 150,
          child: Row(
            children: [
              Expanded(child: TextField(controller: _controller, keyboardType: TextInputType.number)),
              IconButton(icon: Icon(_isSaving ? Icons.sync : Icons.save), onPressed: _isSaving ? null : _saveRate),
            ],
          ),
        ),
      ),
    );
  }
}
