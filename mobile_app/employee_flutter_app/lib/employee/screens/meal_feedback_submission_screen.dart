import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  late DateTime _selectedDate;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _submittingReservationId;
  String? _errorMessage;

  List<FeedbackEligibleReservation> _items = [];

  final Map<String, int> _ratings = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _anonymous = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = _resolveOperationalReferenceDate();
    _loadData();
  }

  DateTime _resolveOperationalReferenceDate() {
    final now = DateTime.now();
    if (now.hour < 6) {
      return now.subtract(const Duration(days: 1));
    }
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

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

      for (final item in data) {
        _ratings[item.reservationId] = 0;
        _controllers[item.reservationId] = TextEditingController();
        _anonymous[item.reservationId] = false;
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
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
      await _loadData();
    }
  }

  Future<void> _submit(FeedbackEligibleReservation item) async {
    if (_isSubmitting) return;

    final rating = _ratings[item.reservationId] ?? 0;

    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select rating')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submittingReservationId = item.reservationId;
    });

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
        feedbackText: _controllers[item.reservationId]?.text.trim() ?? '',
        issueType: '',
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
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingReservationId = null;
        });
      }
    }
  }

  String _formatDate(DateTime value) {
    return DateFormat('dd MMM yyyy').format(value);
  }

  String _labelize(String value) {
    if (value.trim().isEmpty) return '—';

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1);
        })
        .join(' ');
  }

  Widget _buildStars(String id) {
    final rating = _ratings[id] ?? 0;
    final isThisSubmitting = _submittingReservationId == id;

    return Row(
      children: List.generate(5, (i) {
        return IconButton(
          icon: Icon(
            i < rating ? Icons.star : Icons.star_border,
            color: Colors.orange,
          ),
          onPressed: (_isSubmitting && !isThisSubmitting)
              ? null
              : isThisSubmitting
                  ? null
                  : () {
                      setState(() {
                        _ratings[id] = i + 1;
                      });
                    },
        );
      }),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(_formatDate(_selectedDate)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Meal Feedback',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            onPressed: (_isLoading || _isSubmitting) ? null : _loadData,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(FeedbackEligibleReservation item) {
    final already = item.alreadySubmitted;
    final isThisSubmitting = _submittingReservationId == item.reservationId;
    final canSubmit = item.isIssued && !already && !_isSubmitting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.itemName.isEmpty ? 'Meal' : item.itemName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('${_labelize(item.mealType)} • ${_labelize(item.diningMode)}'),
            Text('Qty: ${item.quantity}'),
            Text('Status: ${_labelize(item.status)}'),
            if (already)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Feedback already submitted',
                  style: TextStyle(color: Colors.green),
                ),
              )
            else if (!item.isIssued)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Feedback can be submitted after meal is issued',
                  style: TextStyle(color: Colors.orange),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              Text(
                'Overall Rating',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              _buildStars(item.reservationId),
              const SizedBox(height: 8),
              TextField(
                controller: _controllers[item.reservationId],
                enabled: !_isSubmitting,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                  hintText: 'Write feedback...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _anonymous[item.reservationId],
                    onChanged: _isSubmitting
                        ? null
                        : (v) {
                            setState(() {
                              _anonymous[item.reservationId] = v ?? false;
                            });
                          },
                  ),
                  const Text('Submit anonymously'),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: canSubmit ? () => _submit(item) : null,
                    child: isThisSubmitting
                        ? const Text('Submitting...')
                        : const Text('Submit'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No eligible meals found for ${_formatDate(_selectedDate)}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Meal Feedback'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Meal Feedback'),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _isSubmitting ? null : _pickDate,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isSubmitting ? null : _loadData,
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
        title: const Text('Meal Feedback'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _isSubmitting ? null : _pickDate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isSubmitting ? null : _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (c, i) => _buildItemCard(_items[i]),
                  ),
          ),
        ],
      ),
    );
  }
}
