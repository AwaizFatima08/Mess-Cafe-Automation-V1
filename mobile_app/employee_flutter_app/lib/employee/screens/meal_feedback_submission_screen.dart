import 'package:flutter/material.dart';

import '../../services/meal_feedback_service.dart';

class MealFeedbackSubmissionScreen extends StatefulWidget {
  final String employeeNumber;
  final String employeeName;
  final String userUid;

  const MealFeedbackSubmissionScreen({
    super.key,
    required this.employeeNumber,
    required this.employeeName,
    required this.userUid,
  });

  @override
  State<MealFeedbackSubmissionScreen> createState() =>
      _MealFeedbackSubmissionScreenState();
}

class _MealFeedbackSubmissionScreenState
    extends State<MealFeedbackSubmissionScreen> {
  final MealFeedbackService _service = MealFeedbackService();

  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 1));
  bool _isLoading = true;
  String? _errorMessage;

  List<FeedbackEligibleReservation> _items = [];

  final Map<String, int> _ratings = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _anonymous = {};
  final Map<String, String> _issueType = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _service.getFeedbackEligibleReservations(
        employeeNumber: widget.employeeNumber,
        reservationDate: _selectedDate,
        submittedByUid: widget.userUid,
      );

      for (final c in _controllers.values) {
        c.dispose();
      }
      _ratings.clear();
      _controllers.clear();
      _anonymous.clear();
      _issueType.clear();

      for (final item in data) {
        _ratings[item.reservationId] = 0;
        _controllers[item.reservationId] = TextEditingController();
        _anonymous[item.reservationId] = false;
        _issueType[item.reservationId] = '';
      }

      if (!mounted) return;

      setState(() {
        _items = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _items = [];
        _isLoading = false;
        _errorMessage = 'Failed to load meal feedback screen: $e';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadData();
    }
  }

  Future<void> _submit(FeedbackEligibleReservation item) async {
    final rating = _ratings[item.reservationId] ?? 0;

    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select rating')),
      );
      return;
    }

    try {
      await _service.submitFeedback(
        reservationId: item.reservationId,
        submittedByUid: widget.userUid,
        submittedByName: widget.employeeName,
        employeeNumber: widget.employeeNumber,
        employeeName: widget.employeeName,
        reservationDate: item.reservationDate,
        mealType: item.mealType,
        menuItemId: item.menuItemId,
        itemName: item.itemName,
        category: item.category,
        rating: rating,
        feedbackText: _controllers[item.reservationId]?.text ?? '',
        issueType: _issueType[item.reservationId] ?? '',
        isAnonymous: _anonymous[item.reservationId] ?? false,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Feedback submit failed: $e')),
      );
    }
  }

  Widget _buildStars(String id) {
    final rating = _ratings[id] ?? 0;

    return Row(
      children: List.generate(5, (i) {
        return IconButton(
          icon: Icon(
            i < rating ? Icons.star : Icons.star_border,
            color: Colors.orange,
          ),
          onPressed: () {
            setState(() {
              _ratings[id] = i + 1;
            });
          },
        );
      }),
    );
  }

  Widget _buildItemCard(FeedbackEligibleReservation item) {
    final already = item.alreadySubmitted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.itemName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("${item.mealType} • ${item.diningMode}"),
            Text("Qty: ${item.quantity}"),
            Text("Status: ${item.status}"),

            if (already)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Feedback already submitted",
                  style: TextStyle(color: Colors.green),
                ),
              )
            else ...[
              _buildStars(item.reservationId),
              DropdownButton<String>(
                value: _issueType[item.reservationId],
                hint: const Text("Issue Type (optional)"),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: "", child: Text("None")),
                  DropdownMenuItem(value: "taste", child: Text("Taste")),
                  DropdownMenuItem(value: "quality", child: Text("Quality")),
                  DropdownMenuItem(value: "quantity", child: Text("Quantity")),
                  DropdownMenuItem(value: "service", child: Text("Service")),
                ],
                onChanged: (v) {
                  setState(() {
                    _issueType[item.reservationId] = v ?? '';
                  });
                },
              ),
              TextField(
                controller: _controllers[item.reservationId],
                decoration: const InputDecoration(
                  hintText: "Write feedback...",
                ),
              ),
              Row(
                children: [
                  Checkbox(
                    value: _anonymous[item.reservationId],
                    onChanged: (v) {
                      setState(() {
                        _anonymous[item.reservationId] = v ?? false;
                      });
                    },
                  ),
                  const Text("Submit anonymously"),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _submit(item),
                    child: const Text("Submit"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Meal Feedback"),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _pickDate,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meal Feedback"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text("No eligible meals found"))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (c, i) => _buildItemCard(_items[i]),
            ),
    );
  }
}
