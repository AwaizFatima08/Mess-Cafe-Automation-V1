import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
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
  final TextEditingController _searchController = TextEditingController();

  late DateTime _selectedDate;

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  String? _issuingReservationId;
  String? _errorMessage;

  final Map<String, _DashboardCacheEntry> _dateCache = {};

  List<_ReservationRecord> _allReservations = [];
  List<_ReservationRecord> _pendingReservations = [];
  List<_ReservationRecord> _issuedReservations = [];

  _DashboardMetrics _metrics = _DashboardMetrics.empty();

  String _searchQuery = '';
  String _mealFilter = 'all';
  String _reservationCategoryFilter = 'all';
  String _diningModeFilter = 'all';
  String _queueTab = 'pending';
  String _sortMode = 'pending_first';

  bool get _isIssuingAny => _issuingReservationId != null;

  @override
  void initState() {
    super.initState();
    _selectedDate = _resolveOperationalReferenceDate();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _resolveOperationalReferenceDate() {
    final now = DateTime.now();
    if (now.hour < 6) {
      return _normalizeDate(now.subtract(const Duration(days: 1)));
    }
    return _normalizeDate(now);
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
    if (value is double) return value.round();
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }

  double _readDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse((value ?? '0').toString()) ?? 0.0;
  }

  DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  double _resolveAmount(Map<String, dynamic> data) {
    final explicitAmount = _readDouble(data['amount']);
    if (explicitAmount > 0) {
      return explicitAmount;
    }

    final unitRate = _readDouble(data['unit_rate']);
    final quantity = _readInt(data['quantity']);

    if (unitRate > 0 && quantity > 0) {
      return unitRate * quantity;
    }

    return 0.0;
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
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
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
    final category = _reservationCategoryLabel(
      _normalizedString(data['reservation_category']),
    );
    final name = _subjectDisplayName(data);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
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
    if (_issuingReservationId != null) return;

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

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No authenticated user found.')),
      );
      return;
    }

    setState(() {
      _issuingReservationId = recordId;
    });

    try {
      await _mealReservationService.markReservationIssued(
        reservationId: recordId,
        issuedByUid: authUser.uid,
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
            'issued_by_uid': authUser.uid,
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
          _issuingReservationId = null;
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

  String _formatCurrency(dynamic value) {
    if (value is int) return value.toDouble().toStringAsFixed(2);
    if (value is double) return value.toStringAsFixed(2);

    final parsed = double.tryParse((value ?? '').toString());
    return (parsed ?? 0).toStringAsFixed(2);
  }

  bool _matchesSearch(_ReservationRecord record) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;

    final data = record.data;
    final haystack = <String>[
      (data['employee_number'] ?? '').toString(),
      (data['employee_name'] ?? '').toString(),
      (data['guest_name'] ?? '').toString(),
      (data['host_employee_number'] ?? '').toString(),
      (data['host_employee_name'] ?? '').toString(),
      (data['option_label'] ?? '').toString(),
      (data['item_name'] ?? '').toString(),
      (data['created_by_employee_number'] ?? '').toString(),
      (data['created_by_name'] ?? '').toString(),
    ].join(' | ').toLowerCase();

    return haystack.contains(q);
  }

  bool _matchesFilters(_ReservationRecord record) {
    final data = record.data;

    if (_mealFilter != 'all' &&
        _normalizedString(data['meal_type']) != _mealFilter) {
      return false;
    }

    if (_reservationCategoryFilter != 'all' &&
        _normalizedString(data['reservation_category']) !=
            _reservationCategoryFilter) {
      return false;
    }

    if (_diningModeFilter != 'all' &&
        _normalizedString(data['dining_mode']) != _diningModeFilter) {
      return false;
    }

    return _matchesSearch(record);
  }

  List<_ReservationRecord> _sortRecords(List<_ReservationRecord> records) {
    final sorted = List<_ReservationRecord>.from(records);

    switch (_sortMode) {
      case 'latest_first':
        sorted.sort((a, b) => _reservationSort(b, a));
        break;
      case 'employee_number':
        sorted.sort((a, b) {
          final aEmp = (a.data['employee_number'] ?? '').toString();
          final bEmp = (b.data['employee_number'] ?? '').toString();
          return aEmp.compareTo(bEmp);
        });
        break;
      case 'name':
        sorted.sort((a, b) {
          final aName = _subjectDisplayName(a.data).toLowerCase();
          final bName = _subjectDisplayName(b.data).toLowerCase();
          return aName.compareTo(bName);
        });
        break;
      case 'pending_first':
      default:
        sorted.sort(_reservationSort);
        break;
    }

    return sorted;
  }

  List<_ReservationRecord> get _filteredPendingReservations {
    return _sortRecords(
      _pendingReservations.where(_matchesFilters).toList(),
    );
  }

  List<_ReservationRecord> get _filteredIssuedReservations {
    return _sortRecords(
      _issuedReservations.where(_matchesFilters).toList(),
    );
  }

  List<_ReservationRecord> get _activeQueue {
    return _queueTab == 'issued'
        ? _filteredIssuedReservations
        : _filteredPendingReservations;
  }

  int get _filteredPendingQuantity {
    return _filteredPendingReservations.fold<int>(
      0,
      (runningTotal, record) => runningTotal + _readInt(record.data['quantity']),
    );
  }

  int get _filteredIssuedQuantity {
    return _filteredIssuedReservations.fold<int>(
      0,
      (runningTotal, record) => runningTotal + _readInt(record.data['quantity']),
    );
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _mealFilter = 'all';
      _reservationCategoryFilter = 'all';
      _diningModeFilter = 'all';
      _sortMode = 'pending_first';
      _searchController.clear();
    });
  }

  Widget _buildHeaderCard() {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        gradient: const LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Wrap(
          runSpacing: AppSpacing.lg,
          spacing: AppSpacing.lg,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.visibleAppName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Mess Operations Dashboard',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Signed in as: ${widget.userEmail}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Date: ${_formatDate(_selectedDate)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Reservations loaded: ${_allReservations.length}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                  if (_isRefreshing) ...[
                    const SizedBox(height: AppSpacing.md),
                    const SizedBox(
                      width: 220,
                      child: LinearProgressIndicator(
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _isRefreshing || _isIssuingAny ? null : _goToPreviousDate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
                OutlinedButton.icon(
                  onPressed: _isRefreshing || _isIssuingAny ? null : _pickDate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Select Date'),
                ),
                OutlinedButton.icon(
                  onPressed: _isRefreshing || _isIssuingAny ? null : _goToNextDate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
                ElevatedButton.icon(
                  onPressed: _isRefreshing || _isIssuingAny
                      ? null
                      : () => _loadDashboardData(forceRefresh: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Icon(icon, size: 26, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
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
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
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
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Total $total',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.info,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
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
        padding: const EdgeInsets.all(AppSpacing.lg),
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
        padding: const EdgeInsets.all(AppSpacing.lg),
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
        padding: const EdgeInsets.all(AppSpacing.lg),
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
        padding: const EdgeInsets.all(AppSpacing.lg),
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
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
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

  Widget _buildFiltersCard() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Queue Filters',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Search by employee number, name, guest, host, or option label. Then narrow by meal, category, and dining mode.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by employee no. / name / guest / option',
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _mealFilter,
                    decoration: const InputDecoration(
                      labelText: 'Meal',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Meals')),
                      DropdownMenuItem(
                          value: 'breakfast', child: Text('Breakfast')),
                      DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                      DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _mealFilter = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String>(
                    initialValue: _reservationCategoryFilter,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Categories')),
                      DropdownMenuItem(
                          value: 'employee', child: Text('Employee')),
                      DropdownMenuItem(
                          value: 'official_guest', child: Text('Official Guest')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _reservationCategoryFilter = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _diningModeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Dining Mode',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Modes')),
                      DropdownMenuItem(
                          value: 'dine_in', child: Text('Dine In')),
                      DropdownMenuItem(
                          value: 'takeaway', child: Text('Takeaway')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _diningModeFilter = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: _sortMode,
                    decoration: const InputDecoration(
                      labelText: 'Sort',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'pending_first',
                        child: Text('Meal order'),
                      ),
                      DropdownMenuItem(
                        value: 'latest_first',
                        child: Text('Latest first'),
                      ),
                      DropdownMenuItem(
                        value: 'employee_number',
                        child: Text('Employee no.'),
                      ),
                      DropdownMenuItem(
                        value: 'name',
                        child: Text('Name'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _sortMode = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                Chip(
                  label: Text(
                    'Pending: ${_filteredPendingReservations.length} line(s) / $_filteredPendingQuantity qty',
                  ),
                ),
                Chip(
                  label: Text(
                    'Issued: ${_filteredIssuedReservations.length} line(s) / $_filteredIssuedQuantity qty',
                  ),
                ),
                if (_searchQuery.isNotEmpty ||
                    _mealFilter != 'all' ||
                    _reservationCategoryFilter != 'all' ||
                    _diningModeFilter != 'all' ||
                    _sortMode != 'pending_first')
                  ActionChip(
                    onPressed: _clearFilters,
                    label: const Text('Clear Filters'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueSectionCard() {
    final queueRecords = _activeQueue;
    final isPendingTab = _queueTab == 'pending';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meal Issuance Queue',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Use search and filters to reach a specific employee quickly during rush operations.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'pending',
                  icon: Icon(Icons.pending_actions_outlined),
                  label: Text('Pending'),
                ),
                ButtonSegment<String>(
                  value: 'issued',
                  icon: Icon(Icons.verified_outlined),
                  label: Text('Issued'),
                ),
              ],
              selected: <String>{_queueTab},
              onSelectionChanged: (selection) {
                setState(() {
                  _queueTab = selection.first;
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                isPendingTab
                    ? 'Filtered pending lines: ${_filteredPendingReservations.length} • quantity: $_filteredPendingQuantity'
                    : 'Filtered issued lines: ${_filteredIssuedReservations.length} • quantity: $_filteredIssuedQuantity',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (queueRecords.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Text(
                  isPendingTab
                      ? 'No pending reservations match the current filters.'
                      : 'No issued reservations match the current filters.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...queueRecords.map(
                (record) => _ReservationTile(
                  data: record.data,
                  isBusy: _issuingReservationId == record.id,
                  isAnyIssuanceInProgress: _isIssuingAny,
                  actionLabel: isPendingTab ? 'Issue Meal' : 'Issued',
                  actionIcon: isPendingTab
                      ? Icons.check_circle_outline
                      : Icons.verified_outlined,
                  onAction: isPendingTab ? () => _issueMeal(record.id) : null,
                  mealLabelBuilder: _mealLabel,
                  bookingSourceLabelBuilder: _bookingSourceLabel,
                  bookingSubjectTypeLabelBuilder: _bookingSubjectTypeLabel,
                  diningModeLabelBuilder: _diningModeLabel,
                  reservationCategoryLabelBuilder: _reservationCategoryLabel,
                  formatDateTime: _formatDateTime,
                  formatCurrency: _formatCurrency,
                  resolveAmount: _resolveAmount,
                  showIssuedMeta: !isPendingTab,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final width = MediaQuery.of(context).size.width;
    final kpiCrossAxisCount = width >= 1200 ? 4 : 2;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _loadDashboardData(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: kpiCrossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: width >= 1200 ? 2.5 : 2.0,
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
          const SizedBox(height: AppSpacing.lg),
          _buildFiltersCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionTitle(
            'Meal-wise Summary',
            'Breakfast, lunch, and dinner totals with issuance visibility.',
          ),
          _buildMealSection(
            title: 'Breakfast',
            icon: Icons.free_breakfast_outlined,
            total: _metrics.breakfastTotal,
            issued: _metrics.breakfastIssued,
            pending: _metrics.breakfastPending,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildMealSection(
            title: 'Lunch',
            icon: Icons.lunch_dining_outlined,
            total: _metrics.lunchTotal,
            issued: _metrics.lunchIssued,
            pending: _metrics.lunchPending,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildMealSection(
            title: 'Dinner',
            icon: Icons.dinner_dining_outlined,
            total: _metrics.dinnerTotal,
            issued: _metrics.dinnerIssued,
            pending: _metrics.dinnerPending,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionTitle(
            'Operational Segmentation',
            'Employee vs guest, dining mode split, and booking-source visibility.',
          ),
          _buildSegmentationCard(),
          const SizedBox(height: AppSpacing.md),
          _buildDiningModeCard(),
          const SizedBox(height: AppSpacing.md),
          _buildSourceVisibilityCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionTitle(
            'Operator Visibility',
            'Who booked how many lines and quantity on the selected date.',
          ),
          _buildOperatorVisibilityCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildQueueSectionCard(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 42,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage ?? 'Unknown error',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
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
        onPressed: _isRefreshing || _isIssuingAny
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
  final bool isAnyIssuanceInProgress;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final String Function(String) mealLabelBuilder;
  final String Function(String) bookingSourceLabelBuilder;
  final String Function(String) bookingSubjectTypeLabelBuilder;
  final String Function(String) diningModeLabelBuilder;
  final String Function(String) reservationCategoryLabelBuilder;
  final String Function(dynamic) formatDateTime;
  final String Function(dynamic) formatCurrency;
  final double Function(Map<String, dynamic>) resolveAmount;
  final bool showIssuedMeta;

  const _ReservationTile({
    required this.data,
    required this.isBusy,
    required this.isAnyIssuanceInProgress,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.mealLabelBuilder,
    required this.bookingSourceLabelBuilder,
    required this.bookingSubjectTypeLabelBuilder,
    required this.diningModeLabelBuilder,
    required this.reservationCategoryLabelBuilder,
    required this.formatDateTime,
    required this.formatCurrency,
    required this.resolveAmount,
    this.showIssuedMeta = false,
  });

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
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
    final amount = resolveAmount(data);

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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subjectDisplay,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subjectSecondary,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Category: ${reservationCategoryLabelBuilder(reservationCategory)} • Subject: ${bookingSubjectTypeLabelBuilder(bookingSubjectType)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Meal: ${mealLabelBuilder(mealType)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Option: ${optionLabel.isEmpty ? '—' : optionLabel}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Dining Mode: ${diningModeLabelBuilder(diningMode)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Quantity: $quantity',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Amount: ${formatCurrency(amount)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Booked Via: ${bookingSourceLabelBuilder(bookingSource)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Booked By: ${createdByName.isEmpty ? '—' : createdByName}'
              '${createdByRole.isEmpty ? '' : ' • $createdByRole'}'
              '${createdByEmployeeNumber.isEmpty ? '' : ' • $createdByEmployeeNumber'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Created At: ${formatDateTime(data['created_at'])}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (showIssuedMeta) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Issued By: ${issuedByUid.isEmpty ? '—' : issuedByUid}'
                '${issuedByRole.isEmpty ? '' : ' • $issuedByRole'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Issued At: ${formatDateTime(issuedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: (isBusy || isAnyIssuanceInProgress || onAction == null)
                    ? null
                    : onAction,
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
