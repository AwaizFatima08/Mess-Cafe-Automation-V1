import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/meal_feedback_service.dart';

class MealFeedbackDashboardScreen extends StatefulWidget {
  const MealFeedbackDashboardScreen({super.key});

  @override
  State<MealFeedbackDashboardScreen> createState() =>
      _MealFeedbackDashboardScreenState();
}

class _MealFeedbackDashboardScreenState
    extends State<MealFeedbackDashboardScreen> {
  final MealFeedbackService _service = MealFeedbackService();

  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 1));
  bool _isLoading = true;

  MealFeedbackSummary? _summary;
  List<MealFeedbackEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final summary = await _service.getFeedbackSummaryForDate(_selectedDate);
    final entries = await _service.getFeedbackForDate(_selectedDate);

    if (!mounted) return;

    setState(() {
      _summary = summary;
      _entries = entries;
      _isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadData();
    }
  }

  String _fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  Widget _buildHeader() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today),
          label: Text(_fmtDate(_selectedDate)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Meal Feedback Dashboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildSummary(MealFeedbackSummary s) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      childAspectRatio: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _card("Total", s.totalCount),
        _card("Avg Rating", s.averageRating.toStringAsFixed(2)),
        _card("Open", s.openCount),
        _card("Closed", s.closedCount),
      ],
    );
  }

  Widget _card(String title, dynamic value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 5),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatings(MealFeedbackSummary s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Rating Distribution",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...s.ratingBuckets.entries.map((e) {
              return Row(
                children: [
                  Text("${e.key} ⭐"),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: s.totalCount == 0
                          ? 0
                          : e.value / s.totalCount,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text("${e.value}"),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRatings(MealFeedbackSummary s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Item-wise Ratings",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("Item")),
                  DataColumn(label: Text("Category")),
                  DataColumn(label: Text("Count")),
                  DataColumn(label: Text("Avg Rating")),
                  DataColumn(label: Text("Issues")),
                ],
                rows: s.itemSummaries.map((e) {
                  return DataRow(cells: [
                    DataCell(Text(e.itemName)),
                    DataCell(Text(e.category)),
                    DataCell(Text("${e.totalCount}")),
                    DataCell(Text(e.averageRating.toStringAsFixed(2))),
                    DataCell(Text(e.issueTypes.join(", "))),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntries() {
    if (_entries.isEmpty) {
      return const Center(child: Text("No feedback available"));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _entries.length,
      itemBuilder: (context, i) {
        final e = _entries[i];

        return Card(
          child: ListTile(
            title: Text("${e.itemName} (${e.rating}⭐)"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.feedbackText),
                Text("Status: ${e.status}"),
              ],
            ),
            trailing: e.status == 'open'
                ? IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      await _service.closeFeedback(
                        feedbackId: e.id,
                        closedByUid: "admin",
                        closedByName: "Admin",
                      );
                      _loadData();
                    },
                  )
                : const Icon(Icons.check_circle, color: Colors.green),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final s = _summary;

    return Scaffold(
      appBar: AppBar(title: const Text("Feedback Dashboard")),
      body: s == null
          ? const Center(child: Text("No data"))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 10),
                  _buildSummary(s),
                  const SizedBox(height: 10),
                  _buildRatings(s),
                  const SizedBox(height: 10),
                  _buildItemRatings(s),
                  const SizedBox(height: 10),
                  _buildEntries(),
                ],
              ),
            ),
    );
  }
}
