import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/meal_reservation_service.dart';

class DashboardScreen extends StatefulWidget {
  final String userEmail;

  const DashboardScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MealReservationService _mealReservationService =
      MealReservationService();

  late DateTime _selectedDate;

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isIssuing = false;
  String? _errorMessage;

  final Map<String, _DashboardCacheEntry> _dateCache = {};

  List<_ReservationRecord> _allReservations = [];
  List<_ReservationRecord> _pendingReservations = [];
  List<_ReservationRecord> _issuedReservations = [];

  _DashboardMetrics _metrics = _DashboardMetrics.empty();

  @override
  void initState() {
    super.initState();
    _selectedDate = _normalizeDate(DateTime.now());
    _loadDashboardData();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _cacheKeyForDate(DateTime date) {
    final normalized = _normalizeDate(date);
    return '${normalized.year.toString().padLeft(4, '0')}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDashboardData({bool forceRefresh = false}) async {
    final normalizedDate = _normalizeDate(_selectedDate);
    final cacheKey = _cacheKeyForDate(normalizedDate);

    if (!forceRefresh && _dateCache.containsKey(cacheKey)) {
      final cached = _dateCache[cacheKey]!;
      if (!mounted) return;

      setState(() {
        _allReservations = List<_ReservationRecord>.from(cached.allReservations);
        _pendingReservations =
            List<_ReservationRecord>.from(cached.pendingReservations);
        _issuedReservations =
            List<_ReservationRecord>.from(cached.issuedReservations);
        _metrics = cached.metrics;
        _errorMessage = null;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
      return;
    }

    final shouldUseInitialLoader = _allReservations.isEmpty && _isInitialLoading;

    if (!mounted) return;
    setState(() {
      if (shouldUseInitialLoader) {
        _isInitialLoading = true;
      } else {
        _isRefreshing = true;
      }
      _errorMessage = null;
    });

    try {
      final reservationsSnapshot =
          await _mealReservationService.getReservationsForDate(
        reservationDate: normalizedDate,
      );

      final records = reservationsSnapshot.docs
          .map((doc) => _ReservationRecord(
                id: doc.id,
                data: Map<String, dynamic>.from(doc.data()),
              ))
          .toList();

      final metrics = _buildMetrics(records);

      final pending = records.where((record) {
        final status = _normalizedString(record.data['status']);
        final isIssued = record.data['is_issued'] == true;
        return status == 'active' && !isIssued;
      }).toList()
        ..sort(_reservationSort);

      final issued = records.where((record) {
        final status = _normalizedString(record.data['status']);
        final isIssued = record.data['is_issued'] == true;
        return status == 'issued' || isIssued;
      }).toList()
        ..sort((a, b) => _reservationSort(b, a));

      final entry = _DashboardCacheEntry(
        allReservations: List<_ReservationRecord>.from(records),
        pendingReservations: List<_ReservationRecord>.from(pending),
        issuedReservations: List<_ReservationRecord>.from(issued),
        metrics: metrics,
      );

      _dateCache[cacheKey] = entry;

      if (!mounted) return;
      setState(() {
        _allReservations = List<_ReservationRecord>.from(entry.allReservations);
        _pendingReservations =
            List<_ReservationRecord>.from(entry.pendingReservations);
        _issuedReservations =
            List<_ReservationRecord>.from(entry.issuedReservations);
        _metrics = entry.metrics;
        _errorMessage = null;
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load dashboard data: $e';
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    }
  }

  int _reservationSort(_ReservationRecord a, _ReservationRecord b) {
    final aMeal = _mealSortOrder(_normalizedString(a.data['meal_type']));
    final bMeal = _mealSortOrder(_normalizedString(b.data['meal_type']));
    if (aMeal != bMeal) {
      return aMeal.compareTo(bMeal);
    }

    final aCreated = _timestampToDateTime(a.data['created_at']);
    final bCreated = _timestampToDateTime(b.data['created_at']);

    if (aCreated == null && bCreated == null) return 0;
    if (aCreated == null) return 1;
    if (bCreated == null) return -1;

    return aCreated.compareTo(bCreated);
  }

  void _storeSelectedDateCache() {
    final cacheKey = _cacheKeyForDate(_selectedDate);
    _dateCache[cacheKey] = _DashboardCacheEntry(
      allReservations: List<_ReservationRecord>.from(_allReservations),
      pendingReservations: List<_ReservationRecord>.from(_pendingReservations),
      issuedReservations: List<_ReservationRecord>.from(_issuedReservations),
      metrics: _metrics,
    );
  }

  _DashboardMetrics _buildMetrics(List<_ReservationRecord> records) {
    final metrics = _DashboardMetrics.empty();

    for (final record in records) {
      final data = record.data;

      final status = _normalizedString(data['status']);
      final mealType = _normalizedString(data['meal_type']);
      final diningMode = _normalizedString(data['dining_mode']);
      final reservationCategory = _normalizedString(data['reservation_category']);
      final bookingSubjectType = _normalizedString(data['booking_subject_type']);
      final bookingSource = _normalizedString(data['booking_source']);
      final quantity = _readInt(data['quantity']);
      final isIssued = data['is_issued'] == true || status == 'issued';

      if (status == 'cancelled' || quantity <= 0) {
        metrics.cancelledLines += 1;
        metrics.cancelledQuantity += quantity;
        continue;
      }

      metrics.totalLines += 1;
      metrics.totalQuantity += quantity;

      if (isIssued) {
        metrics.issuedLines += 1;
        metrics.issuedQuantity += quantity;
      } else {
        metrics.pendingLines += 1;
        metrics.pendingQuantity += quantity;
      }

      switch (mealType) {
        case 'breakfast':
          metrics.breakfastTotal += quantity;
          if (isIssued) {
            metrics.breakfastIssued += quantity;
          } else {
            metrics.breakfastPending += quantity;
          }
          break;
        case 'lunch':
          metrics.lunchTotal += quantity;
          if (isIssued) {
            metrics.lunchIssued += quantity;
          } else {
            metrics.lunchPending += quantity;
          }
          break;
        case 'dinner':
          metrics.dinnerTotal += quantity;
          if (isIssued) {
            metrics.dinnerIssued += quantity;
          } else {
            metrics.dinnerPending += quantity;
          }
          break;
      }

      switch (diningMode) {
        case 'dine_in':
          metrics.dineInTotal += quantity;
          break;
        case 'takeaway':
          metrics.takeawayTotal += quantity;
          break;
      }

      if (reservationCategory == MealReservationService.categoryEmployee) {
        metrics.employeeTotal += quantity;
      } else if (reservationCategory ==
          MealReservationService.categoryOfficialGuest) {
        metrics.guestTotal += quantity;
      }

      if (bookingSubjectType == MealReservationService.subjectEmployeeSelf) {
        metrics.selfBookedTotal += quantity;
      } else if (bookingSubjectType ==
          MealReservationService.subjectEmployeeProxy) {
        metrics.proxyBookedTotal += quantity;
      } else if (bookingSubjectType ==
          MealReservationService.subjectOfficialGuest) {
        metrics.guestBookedTotal += quantity;
      }

      switch (bookingSource) {
        case MealReservationService.bookingSourceEmployeeApp:
          metrics.employeeAppTotal += quantity;
          break;
        case MealReservationService.bookingSourceSupervisorConsole:
          metrics.supervisorConsoleTotal += quantity;
          break;
        case MealReservationService.bookingSourceAdminConsole:
          metrics.adminConsoleTotal += quantity;
          break;
      }

      final operatorKey = _operatorKey(data);
      final operatorName = _operatorDisplayName(data);
      final operatorRole = _operatorRoleLabel(data);

      final existingOperator = metrics.operatorTotals[operatorKey] ??
          _OperatorMetric(
            operatorKey: operatorKey,
            operatorName: operatorName,
            roleLabel: operatorRole,
            quantity: 0,
            lines: 0,
          );

      metrics.operatorTotals[operatorKey] = existingOperator.copyWith(
        quantity: existingOperator.quantity + quantity,
        lines: existingOperator.lines + 1,
      );
    }

    return metrics;
  }

  String _normalizedString(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }

  DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  int _mealSortOrder(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 1;
      case 'lunch':
        return 2;
      case 'dinner':
        return 3;
      default:
        return 99;
    }
  }

  String _mealLabel(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return mealType.isEmpty ? 'Unknown' : mealType;
    }
  }

  String _reservationCategoryLabel(String value) {
    switch (value) {
      case 'employee':
        return 'Employee';
      case 'official_guest':
        return 'Official Guest';
      default:
        return value.isEmpty ? 'Unknown' : value;
    }
  }

  String _bookingSubjectTypeLabel(String value) {
    switch (value) {
      case 'employee_self':
        return 'Self';
      case 'employee_proxy':
        return 'Proxy';
      case 'official_guest':
        return 'Guest';
      default:
        return value.isEmpty ? 'Unknown' : value;
    }
  }

  String _bookingSourceLabel(String value) {
    switch (value) {
      case 'employee_app':
        return 'Employee App';
      case 'supervisor_console':
        return 'Supervisor Console';
      case 'admin_console':
        return 'Admin Console';
      default:
        return value.isEmpty ? 'Unknown' : value;
    }
  }

  String _diningModeLabel(String value) {
    switch (value) {
      case 'dine_in':
        return 'Dine In';
      case 'takeaway':
        return 'Takeaway';
      default:
        return value.isEmpty ? 'Unknown' : value;
    }
  }

  String _operatorKey(Map<String, dynamic> data) {
    final uid = (data['created_by_uid'] ?? '').toString().trim();
    if (uid.isNotEmpty) {
      return uid;
    }

    final empNo = (data['created_by_employee_number'] ?? '').toString().trim();
    if (empNo.isNotEmpty) {
      return 'emp:$empNo';
    }

    final name = (data['created_by_name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      return 'name:$name';
    }

    return 'unknown_operator';
  }

  String _operatorDisplayName(Map<String, dynamic> data) {
    final name = (data['created_by_name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      return name;
    }

    final empNo = (data['created_by_employee_number'] ?? '').toString().trim();
    if (empNo.isNotEmpty) {
      return 'Employee $empNo';
    }

    final uid = (data['created_by_uid'] ?? '').toString().trim();
    if (uid.isNotEmpty) {
      return uid;
    }

    return 'Unknown Operator';
  }

  String _operatorRoleLabel(Map<String, dynamic> data) {
    final role = _normalizedString(data['created_by_role']);
    if (role.isEmpty) return 'Unknown';
    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = _normalizeDate(picked);
    });

    await _loadDashboardData();
  }

  Future<void> _goToPreviousDate() async {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    await _loadDashboardData();
  }

  Future<void> _goToNextDate() async {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    await _loadDashboardData();
  }

  Future<bool> _confirmIssue(Map<String, dynamic> data) async {
    final mealType = _mealLabel(_normalizedString(data['meal_type']));
    final qty = _readInt(data['quantity']);
    final category =
        _reservationCategoryLabel(_normalizedString(data['reservation_category']));
    final name = _subjectDisplayName(data);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Meal Issuance'),
          content: Text('Issue $qty × $mealType for $name ($category)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Issue Meal'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  String _subjectDisplayName(Map<String, dynamic> data) {
    final reservationCategory =
        _normalizedString(data['reservation_category']).trim();

    if (reservationCategory == 'official_guest') {
      final guest = (data['guest_name'] ?? '').toString().trim();
      return guest.isEmpty ? 'Unnamed Guest' : guest;
    }

    final employee = (data['employee_name'] ?? '').toString().trim();
    if (employee.isNotEmpty) {
      return employee;
    }

    final empNo = (data['employee_number'] ?? '').toString().trim();
    return empNo.isEmpty ? 'Unknown Employee' : 'Employee $empNo';
  }

  Future<void> _issueMeal(String recordId) async {
    if (_isIssuing) return;

    final matches =
        _pendingReservations.where((record) => record.id == recordId).toList();

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reservation is no longer pending. Refreshing...'),
        ),
      );
      await _loadDashboardData(forceRefresh: true);
      return;
    }

    final target = matches.first;
    final confirmed = await _confirmIssue(target.data);
    if (!confirmed) return;

    setState(() {
      _isIssuing = true;
    });

    try {
      await _mealReservationService.markReservationIssued(
        reservationId: recordId,
        issuedByUid: widget.userEmail,
        issuedByRole: 'mess_dashboard_operator',
      );

      final issuedAt = Timestamp.now();

      final updatedAll = _allReservations.map((record) {
        if (record.id != recordId) {
          return record;
        }

        return record.copyWith(
          data: {
            ...record.data,
            'is_issued': true,
            'status': 'issued',
            'issued_at': issuedAt,
            'issued_by_uid': widget.userEmail,
            'issued_by_role': 'mess_dashboard_operator',
          },
        );
      }).toList();

      final rebuiltMetrics = _buildMetrics(updatedAll);

      final updatedPending = updatedAll.where((record) {
        final status = _normalizedString(record.data['status']);
        final isIssued = record.data['is_issued'] == true;
        return status == 'active' && !isIssued;
      }).toList()
        ..sort(_reservationSort);

      final updatedIssued = updatedAll.where((record) {
        final status = _normalizedString(record.data['status']);
        final isIssued = record.data['is_issued'] == true;
        return status == 'issued' || isIssued;
      }).toList()
        ..sort((a, b) => _reservationSort(b, a));

      if (!mounted) return;

      setState(() {
        _allReservations = updatedAll;
        _pendingReservations = updatedPending;
        _issuedReservations = updatedIssued;
        _metrics = rebuiltMetrics;
      });

      _storeSelectedDateCache();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_subjectDisplayName(target.data)} • ${_mealLabel(_normalizedString(target.data['meal_type']))} issued successfully.',
          ),
        ),
      );

      await _loadDashboardData(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Issue failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isIssuing = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  String _formatDateTime(dynamic value) {
    final dt = _timestampToDateTime(value);
    if (dt == null) return '—';

    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$day-$month-$year $hour:$minute';
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mess Operations Dashboard',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Signed in as: ${widget.userEmail}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: ${_formatDate(_selectedDate)}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reservations loaded: ${_allReservations.length}',
                  style: const TextStyle(fontSize: 14),
                ),
                if (_isRefreshing) ...[
                  const SizedBox(height: 8),
                  const SizedBox(
                    width: 180,
                    child: LinearProgressIndicator(),
                  ),
                ],
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _isRefreshing || _isIssuing ? null : _goToPreviousDate,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
                OutlinedButton.icon(
                  onPressed: _isRefreshing || _isIssuing ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Select Date'),
                ),
                OutlinedButton.icon(
                  onPressed: _isRefreshing || _isIssuing ? null : _goToNextDate,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
                ElevatedButton.icon(
                  onPressed: _isRefreshing || _isIssuing
                      ? null
                      : () => _loadDashboardData(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required int value,
    required IconData icon,
    String? subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required int value,
    IconData? icon,
    bool emphasized = false,
  }) {
    final textStyle = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(label, style: textStyle),
        ),
        Text(
          value.toString(),
          style: emphasized
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildMealSection({
    required String title,
    required IconData icon,
    required int total,
    required int issued,
    required int pending,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Total $total',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              label: 'Issued',
              value: issued,
              icon: Icons.check_circle_outline,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Pending',
              value: pending,
              icon: Icons.pending_actions_outlined,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Total',
              value: total,
              icon: Icons.summarize_outlined,
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMetricRow(
              label: 'Employee Reservations',
              value: _metrics.employeeTotal,
              icon: Icons.badge_outlined,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Guest Reservations',
              value: _metrics.guestTotal,
              icon: Icons.groups_outlined,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Self Booked',
              value: _metrics.selfBookedTotal,
              icon: Icons.person_outline,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Proxy Booked',
              value: _metrics.proxyBookedTotal,
              icon: Icons.supervisor_account_outlined,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Guest Booked',
              value: _metrics.guestBookedTotal,
              icon: Icons.group_add_outlined,
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiningModeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMetricRow(
              label: 'Dine In',
              value: _metrics.dineInTotal,
              icon: Icons.restaurant_outlined,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Takeaway',
              value: _metrics.takeawayTotal,
              icon: Icons.takeout_dining_outlined,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Total',
              value: _metrics.dineInTotal + _metrics.takeawayTotal,
              icon: Icons.summarize_outlined,
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceVisibilityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMetricRow(
              label: 'Employee App',
              value: _metrics.employeeAppTotal,
              icon: Icons.phone_android_outlined,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Supervisor Console',
              value: _metrics.supervisorConsoleTotal,
              icon: Icons.support_agent_outlined,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Admin Console',
              value: _metrics.adminConsoleTotal,
              icon: Icons.admin_panel_settings_outlined,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Total',
              value: _metrics.employeeAppTotal +
                  _metrics.supervisorConsoleTotal +
                  _metrics.adminConsoleTotal,
              icon: Icons.summarize_outlined,
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorVisibilityCard() {
    final operatorList = _metrics.operatorTotals.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (operatorList.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('No operator activity found for selected date.'),
              )
            else
              ...operatorList.take(8).map(
                (operator) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.person_outline, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              operator.operatorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${operator.roleLabel} • ${operator.lines} line(s)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        operator.quantity.toString(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingIssuanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending Issuance Queue',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Pending lines: ${_metrics.pendingLines} • Pending quantity: ${_metrics.pendingQuantity}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_pendingReservations.isEmpty)
              const Text('No pending reservations.')
            else
              ..._pendingReservations.map(
                (record) => _ReservationTile(
                  data: record.data,
                  isBusy: _isIssuing,
                  actionLabel: 'Issue Meal',
                  actionIcon: Icons.check_circle_outline,
                  onAction: () => _issueMeal(record.id),
                  mealLabelBuilder: _mealLabel,
                  bookingSourceLabelBuilder: _bookingSourceLabel,
                  bookingSubjectTypeLabelBuilder: _bookingSubjectTypeLabel,
                  diningModeLabelBuilder: _diningModeLabel,
                  reservationCategoryLabelBuilder: _reservationCategoryLabel,
                  formatDateTime: _formatDateTime,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuedSectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Issued Meals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Issued lines: ${_metrics.issuedLines} • Issued quantity: ${_metrics.issuedQuantity}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_issuedReservations.isEmpty)
              const Text('No issued reservations.')
            else
              ..._issuedReservations.take(20).map(
                (record) => _ReservationTile(
                  data: record.data,
                  isBusy: false,
                  actionLabel: 'Issued',
                  actionIcon: Icons.verified_outlined,
                  onAction: null,
                  mealLabelBuilder: _mealLabel,
                  bookingSourceLabelBuilder: _bookingSourceLabel,
                  bookingSubjectTypeLabelBuilder: _bookingSubjectTypeLabel,
                  diningModeLabelBuilder: _diningModeLabel,
                  reservationCategoryLabelBuilder: _reservationCategoryLabel,
                  formatDateTime: _formatDateTime,
                  showIssuedMeta: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: () => _loadDashboardData(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width >= 1100 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
                MediaQuery.of(context).size.width >= 1100 ? 2.5 : 2.1,
            children: [
              _buildKpiCard(
                title: 'Total Quantity',
                value: _metrics.totalQuantity,
                icon: Icons.summarize_outlined,
                subtitle: 'All active + issued lines',
              ),
              _buildKpiCard(
                title: 'Issued Quantity',
                value: _metrics.issuedQuantity,
                icon: Icons.check_circle_outline,
                subtitle: 'Ready served / issued',
              ),
              _buildKpiCard(
                title: 'Pending Quantity',
                value: _metrics.pendingQuantity,
                icon: Icons.pending_actions_outlined,
                subtitle: 'Still awaiting issuance',
              ),
              _buildKpiCard(
                title: 'Cancelled Quantity',
                value: _metrics.cancelledQuantity,
                icon: Icons.cancel_outlined,
                subtitle: 'Cancelled lines for selected date',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionTitle(
            'Meal-wise Summary',
            'Breakfast, lunch and dinner totals with issuance visibility.',
          ),
          _buildMealSection(
            title: 'Breakfast',
            icon: Icons.free_breakfast_outlined,
            total: _metrics.breakfastTotal,
            issued: _metrics.breakfastIssued,
            pending: _metrics.breakfastPending,
          ),
          const SizedBox(height: 12),
          _buildMealSection(
            title: 'Lunch',
            icon: Icons.lunch_dining_outlined,
            total: _metrics.lunchTotal,
            issued: _metrics.lunchIssued,
            pending: _metrics.lunchPending,
          ),
          const SizedBox(height: 12),
          _buildMealSection(
            title: 'Dinner',
            icon: Icons.dinner_dining_outlined,
            total: _metrics.dinnerTotal,
            issued: _metrics.dinnerIssued,
            pending: _metrics.dinnerPending,
          ),
          const SizedBox(height: 16),
          _buildSectionTitle(
            'Operational Segmentation',
            'Employee vs guest vs proxy flow, dining mode split, and booking-source visibility.',
          ),
          _buildSegmentationCard(),
          const SizedBox(height: 12),
          _buildDiningModeCard(),
          const SizedBox(height: 12),
          _buildSourceVisibilityCard(),
          const SizedBox(height: 16),
          _buildSectionTitle(
            'Operator Visibility',
            'Who booked how many lines and quantity on the selected date.',
          ),
          _buildOperatorVisibilityCard(),
          const SizedBox(height: 16),
          _buildPendingIssuanceCard(),
          const SizedBox(height: 16),
          _buildIssuedSectionCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 42,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Unknown error',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _loadDashboardData(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
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
    if (_isInitialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && _allReservations.isEmpty) {
      return Scaffold(
        body: _buildErrorState(),
      );
    }

    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRefreshing || _isIssuing
            ? null
            : () => _loadDashboardData(forceRefresh: true),
        icon: _isRefreshing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        label: Text(_isRefreshing ? 'Refreshing' : 'Refresh'),
      ),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isBusy;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final String Function(String) mealLabelBuilder;
  final String Function(String) bookingSourceLabelBuilder;
  final String Function(String) bookingSubjectTypeLabelBuilder;
  final String Function(String) diningModeLabelBuilder;
  final String Function(String) reservationCategoryLabelBuilder;
  final String Function(dynamic) formatDateTime;
  final bool showIssuedMeta;

  const _ReservationTile({
    required this.data,
    required this.isBusy,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.mealLabelBuilder,
    required this.bookingSourceLabelBuilder,
    required this.bookingSubjectTypeLabelBuilder,
    required this.diningModeLabelBuilder,
    required this.reservationCategoryLabelBuilder,
    required this.formatDateTime,
    this.showIssuedMeta = false,
  });

  int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }

  String _value(dynamic value) {
    return (value ?? '').toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final reservationCategory =
        _value(data['reservation_category']).toLowerCase();
    final bookingSubjectType = _value(data['booking_subject_type']).toLowerCase();
    final bookingSource = _value(data['booking_source']).toLowerCase();
    final mealType = _value(data['meal_type']).toLowerCase();
    final diningMode = _value(data['dining_mode']).toLowerCase();

    final employeeName = _value(data['employee_name']);
    final employeeNumber = _value(data['employee_number']);
    final guestName = _value(data['guest_name']);
    final hostEmployeeNumber = _value(data['host_employee_number']);
    final hostEmployeeName = _value(data['host_employee_name']);
    final optionLabel = _value(data['option_label']);
    final quantity = _readInt(data['quantity']);

    final createdByName = _value(data['created_by_name']);
    final createdByRole = _value(data['created_by_role']);
    final createdByEmployeeNumber = _value(data['created_by_employee_number']);

    final issuedByUid = _value(data['issued_by_uid']);
    final issuedByRole = _value(data['issued_by_role']);
    final issuedAt = data['issued_at'];

    final subjectDisplay = reservationCategory == 'official_guest'
        ? (guestName.isNotEmpty ? guestName : 'Unnamed Guest')
        : (employeeName.isNotEmpty ? employeeName : 'Unknown Employee');

    final subjectSecondary = reservationCategory == 'official_guest'
        ? 'Host: ${hostEmployeeName.isNotEmpty ? hostEmployeeName : '—'}'
            '${hostEmployeeNumber.isNotEmpty ? ' ($hostEmployeeNumber)' : ''}'
        : 'Employee No: ${employeeNumber.isEmpty ? '—' : employeeNumber}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: showIssuedMeta ? Colors.green.withValues(alpha: 0.04) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subjectDisplay,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(subjectSecondary),
            const SizedBox(height: 4),
            Text(
              'Category: ${reservationCategoryLabelBuilder(reservationCategory)}'
              ' • Subject: ${bookingSubjectTypeLabelBuilder(bookingSubjectType)}',
            ),
            const SizedBox(height: 4),
            Text('Meal: ${mealLabelBuilder(mealType)}'),
            const SizedBox(height: 4),
            Text('Option: ${optionLabel.isEmpty ? '—' : optionLabel}'),
            const SizedBox(height: 4),
            Text('Dining Mode: ${diningModeLabelBuilder(diningMode)}'),
            const SizedBox(height: 4),
            Text('Quantity: $quantity'),
            const SizedBox(height: 4),
            Text('Booked Via: ${bookingSourceLabelBuilder(bookingSource)}'),
            const SizedBox(height: 4),
            Text(
              'Booked By: ${createdByName.isEmpty ? '—' : createdByName}'
              '${createdByRole.isEmpty ? '' : ' • $createdByRole'}'
              '${createdByEmployeeNumber.isEmpty ? '' : ' • $createdByEmployeeNumber'}',
            ),
            const SizedBox(height: 4),
            Text('Created At: ${formatDateTime(data['created_at'])}'),
            if (showIssuedMeta) ...[
              const SizedBox(height: 4),
              Text(
                'Issued By: ${issuedByUid.isEmpty ? '—' : issuedByUid}'
                '${issuedByRole.isEmpty ? '' : ' • $issuedByRole'}',
              ),
              const SizedBox(height: 4),
              Text('Issued At: ${formatDateTime(issuedAt)}'),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isBusy || onAction == null ? null : onAction,
                icon: isBusy && onAction != null
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(actionIcon),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationRecord {
  final String id;
  final Map<String, dynamic> data;

  const _ReservationRecord({
    required this.id,
    required this.data,
  });

  _ReservationRecord copyWith({
    String? id,
    Map<String, dynamic>? data,
  }) {
    return _ReservationRecord(
      id: id ?? this.id,
      data: data ?? this.data,
    );
  }
}

class _DashboardMetrics {
  int totalLines;
  int totalQuantity;

  int issuedLines;
  int issuedQuantity;

  int pendingLines;
  int pendingQuantity;

  int cancelledLines;
  int cancelledQuantity;

  int breakfastTotal;
  int breakfastIssued;
  int breakfastPending;

  int lunchTotal;
  int lunchIssued;
  int lunchPending;

  int dinnerTotal;
  int dinnerIssued;
  int dinnerPending;

  int dineInTotal;
  int takeawayTotal;

  int employeeTotal;
  int guestTotal;

  int selfBookedTotal;
  int proxyBookedTotal;
  int guestBookedTotal;

  int employeeAppTotal;
  int supervisorConsoleTotal;
  int adminConsoleTotal;

  Map<String, _OperatorMetric> operatorTotals;

  _DashboardMetrics({
    required this.totalLines,
    required this.totalQuantity,
    required this.issuedLines,
    required this.issuedQuantity,
    required this.pendingLines,
    required this.pendingQuantity,
    required this.cancelledLines,
    required this.cancelledQuantity,
    required this.breakfastTotal,
    required this.breakfastIssued,
    required this.breakfastPending,
    required this.lunchTotal,
    required this.lunchIssued,
    required this.lunchPending,
    required this.dinnerTotal,
    required this.dinnerIssued,
    required this.dinnerPending,
    required this.dineInTotal,
    required this.takeawayTotal,
    required this.employeeTotal,
    required this.guestTotal,
    required this.selfBookedTotal,
    required this.proxyBookedTotal,
    required this.guestBookedTotal,
    required this.employeeAppTotal,
    required this.supervisorConsoleTotal,
    required this.adminConsoleTotal,
    required this.operatorTotals,
  });

  factory _DashboardMetrics.empty() {
    return _DashboardMetrics(
      totalLines: 0,
      totalQuantity: 0,
      issuedLines: 0,
      issuedQuantity: 0,
      pendingLines: 0,
      pendingQuantity: 0,
      cancelledLines: 0,
      cancelledQuantity: 0,
      breakfastTotal: 0,
      breakfastIssued: 0,
      breakfastPending: 0,
      lunchTotal: 0,
      lunchIssued: 0,
      lunchPending: 0,
      dinnerTotal: 0,
      dinnerIssued: 0,
      dinnerPending: 0,
      dineInTotal: 0,
      takeawayTotal: 0,
      employeeTotal: 0,
      guestTotal: 0,
      selfBookedTotal: 0,
      proxyBookedTotal: 0,
      guestBookedTotal: 0,
      employeeAppTotal: 0,
      supervisorConsoleTotal: 0,
      adminConsoleTotal: 0,
      operatorTotals: <String, _OperatorMetric>{},
    );
  }
}

class _OperatorMetric {
  final String operatorKey;
  final String operatorName;
  final String roleLabel;
  final int quantity;
  final int lines;

  const _OperatorMetric({
    required this.operatorKey,
    required this.operatorName,
    required this.roleLabel,
    required this.quantity,
    required this.lines,
  });

  _OperatorMetric copyWith({
    String? operatorKey,
    String? operatorName,
    String? roleLabel,
    int? quantity,
    int? lines,
  }) {
    return _OperatorMetric(
      operatorKey: operatorKey ?? this.operatorKey,
      operatorName: operatorName ?? this.operatorName,
      roleLabel: roleLabel ?? this.roleLabel,
      quantity: quantity ?? this.quantity,
      lines: lines ?? this.lines,
    );
  }
}

class _DashboardCacheEntry {
  final List<_ReservationRecord> allReservations;
  final List<_ReservationRecord> pendingReservations;
  final List<_ReservationRecord> issuedReservations;
  final _DashboardMetrics metrics;

  const _DashboardCacheEntry({
    required this.allReservations,
    required this.pendingReservations,
    required this.issuedReservations,
    required this.metrics,
  });
}
