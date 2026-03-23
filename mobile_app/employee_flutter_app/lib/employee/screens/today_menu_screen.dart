import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../admin/services/menu_resolver_service.dart';
import '../../models/daily_resolved_menu.dart';
import '../../models/resolved_meal_option.dart';
import '../../services/employee_identity_service.dart';
import '../../services/meal_reservation_service.dart';
import '../../services/user_profile_service.dart';

class TodayMenuScreen extends StatefulWidget {
  final String userEmail;
  final String initialDiningMode;

  const TodayMenuScreen({
    super.key,
    required this.userEmail,
    this.initialDiningMode = 'dine_in',
  });

  @override
  State<TodayMenuScreen> createState() => _TodayMenuScreenState();
}

class _TodayMenuScreenState extends State<TodayMenuScreen> {
  final MenuResolverService _menuResolverService = MenuResolverService();
  final MealReservationService _mealReservationService =
      MealReservationService();
  final EmployeeIdentityService _employeeIdentityService =
      EmployeeIdentityService();
  final UserProfileService _userProfileService = UserProfileService();

  late DateTime _selectedDate;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _identityWarning;

  DailyResolvedMenu? _dailyMenu;
  AppUserProfile? _userProfile;
  EmployeeIdentityResult? _identityResult;

  final Map<String, Map<String, _MealSelectionDraft>> _draftsByMeal = {
    'breakfast': <String, _MealSelectionDraft>{},
    'lunch': <String, _MealSelectionDraft>{},
    'dinner': <String, _MealSelectionDraft>{},
  };

  final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _existingReservationsByMeal = {
    'breakfast': <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    'lunch': <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    'dinner': <QueryDocumentSnapshot<Map<String, dynamic>>>[],
  };

  final Map<String, bool> _isEditModeByMeal = {
    'breakfast': false,
    'lunch': false,
    'dinner': false,
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = _normalizeDate(DateTime.now());
    _loadScreenData();
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Future<void> _loadScreenData({bool forceRefresh = false}) async {
    final normalizedDate = _normalizeDate(_selectedDate);

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _identityWarning = null;
      });
    }

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        throw Exception('No authenticated user found.');
      }

      final results = await Future.wait<dynamic>([
        _menuResolverService.getBookingMenuForDate(normalizedDate),
        _userProfileService.resolveCurrentUserProfile(authUid: authUser.uid),
        _employeeIdentityService.resolveByAuthUid(authUser.uid),
      ]);

      final menu = results[0] as DailyResolvedMenu?;
      final userProfile = results[1] as AppUserProfile?;
      final identityResult = results[2] as EmployeeIdentityResult;

      String? identityWarning;
      if (!identityResult.found) {
        identityWarning =
            'Employee linkage is incomplete. Menu can be viewed, but reservation save is disabled until users.employee_number and employees linkage is correct.';
      }

      final existingReservationsByMeal =
          <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{
        'breakfast': <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        'lunch': <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        'dinner': <QueryDocumentSnapshot<Map<String, dynamic>>>[],
      };

      if (identityResult.found &&
          identityResult.employeeNumber != null &&
          identityResult.employeeNumber!.trim().isNotEmpty) {
        final reservationsSnapshot =
            await _mealReservationService.getReservationsForEmployeeDate(
          employeeNumber: identityResult.employeeNumber!.trim(),
          reservationDate: normalizedDate,
        );

        for (final doc in reservationsSnapshot.docs) {
          final data = doc.data();

          final mealType =
              (data['meal_type'] ?? '').toString().trim().toLowerCase();
          final status = (data['status'] ?? '').toString().trim().toLowerCase();

          if (mealType.isEmpty || status == 'cancelled') {
            continue;
          }

          if (existingReservationsByMeal.containsKey(mealType)) {
            existingReservationsByMeal[mealType]!.add(doc);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _dailyMenu = menu;
        _userProfile = userProfile;
        _identityResult = identityResult;
        _identityWarning = identityWarning;

        _existingReservationsByMeal['breakfast']!
          ..clear()
          ..addAll(existingReservationsByMeal['breakfast']!);
        _existingReservationsByMeal['lunch']!
          ..clear()
          ..addAll(existingReservationsByMeal['lunch']!);
        _existingReservationsByMeal['dinner']!
          ..clear()
          ..addAll(existingReservationsByMeal['dinner']!);

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load reservation screen: $e';
        _isLoading = false;
      });
    }
  }

  List<ResolvedMealOption> _optionsForMeal(String mealType) {
    final menu = _dailyMenu;
    if (menu == null) return const [];

    switch (mealType) {
      case 'breakfast':
        return menu.breakfastOptions;
      case 'lunch':
        return menu.lunchOptions;
      case 'dinner':
        return menu.dinnerOptions;
      default:
        return const [];
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
        return mealType;
    }
  }

  String _modeLabel(String value) {
    switch (value) {
      case 'dine_in':
        return 'Dine In';
      case 'takeaway':
        return 'Takeaway';
      default:
        return value;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  String _formatDateTime(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day-$month-$year $hour:$minute';
    }
    return '—';
  }

  String _buildItemsSummary(ResolvedMealOption option) {
    if (option.items.isEmpty) {
      return 'No items listed';
    }

    final names = option.items
        .map((item) {
          return (item['item_name'] ?? item['name'] ?? item['item_id'] ?? '')
              .toString()
              .trim();
        })
        .where((name) => name.isNotEmpty)
        .toList();

    return names.isEmpty ? 'No items listed' : names.join(', ');
  }

  _MealSelectionDraft _draftFor(String mealType, String optionKey) {
    return _draftsByMeal[mealType]![optionKey] ?? const _MealSelectionDraft();
  }

  void _setDraftQuantity({
    required String mealType,
    required String optionKey,
    required String diningMode,
    required int quantity,
  }) {
    final current = _draftFor(mealType, optionKey);
    final safeQuantity = quantity < 0 ? 0 : quantity;

    final updated = diningMode == 'takeaway'
        ? current.copyWith(takeawayQuantity: safeQuantity)
        : current.copyWith(dineInQuantity: safeQuantity);

    setState(() {
      _draftsByMeal[mealType]![optionKey] = updated;
    });
  }

  int _totalDraftQuantityForMeal(String mealType) {
    return _draftsByMeal[mealType]!.values.fold<int>(
      0,
      (runningTotal, draft) =>
          runningTotal + draft.dineInQuantity + draft.takeawayQuantity,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = _normalizeDate(picked);
    });

    await _loadScreenData(forceRefresh: true);
  }

  Future<void> _saveMeal(String mealType) async {
    if (_isSaving) return;

    final identity = _identityResult;
    if (identity == null || !identity.found) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee linkage not resolved. Booking disabled.'),
        ),
      );
      return;
    }

    final employeeNumber = identity.employeeNumber?.trim() ?? '';
    final employeeName = (_userProfile?.employeeName ?? '').trim();

    if (employeeNumber.isEmpty || employeeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee number or employee name is missing.'),
        ),
      );
      return;
    }

    if (_existingReservationsByMeal[mealType]!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_mealLabel(mealType)} already has reservation(s) for selected date.',
          ),
        ),
      );
      return;
    }

    final options = _optionsForMeal(mealType);
    final selectedLines = <ReservationLineInput>[];

    for (final option in options) {
      final draft = _draftFor(mealType, option.optionKey);

      if (draft.dineInQuantity > 0) {
        selectedLines.add(
          ReservationLineInput(
            optionKey: option.optionKey,
            optionLabel: option.optionLabel,
            diningMode: 'dine_in',
            quantity: draft.dineInQuantity,
            menuSnapshot: {
              'option_key': option.optionKey,
              'option_label': option.optionLabel,
              'items': option.items,
            },
          ),
        );
      }

      if (draft.takeawayQuantity > 0) {
        selectedLines.add(
          ReservationLineInput(
            optionKey: option.optionKey,
            optionLabel: option.optionLabel,
            diningMode: 'takeaway',
            quantity: draft.takeawayQuantity,
            menuSnapshot: {
              'option_key': option.optionKey,
              'option_label': option.optionLabel,
              'items': option.items,
            },
          ),
        );
      }
    }

    if (selectedLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select quantity before saving reservation.'),
        ),
      );
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No authenticated user found.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _mealReservationService.createReservationGroup(
        employeeNumber: employeeNumber,
        employeeName: employeeName,
        reservationDate: _selectedDate,
        mealType: mealType,
        lines: selectedLines,
        createdByUid: authUser.uid,
        createdByRole: 'employee',
        createdByEmployeeNumber: employeeNumber,
        createdByName: employeeName,
        bookingSource: MealReservationService.bookingSourceEmployeeApp,
        bookingSubjectType: MealReservationService.subjectEmployeeSelf,
        reservationCategory: MealReservationService.categoryEmployee,
      );

      if (!mounted) return;

      setState(() {
        _draftsByMeal[mealType]!.clear();
        _isEditModeByMeal[mealType] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_mealLabel(mealType)} reservation saved.'),
        ),
      );

      await _loadScreenData(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _cancelMeal(String mealType) async {
    if (_isSaving) return;

    final docs = _existingReservationsByMeal[mealType]!;
    if (docs.isEmpty) return;

    final firstData = docs.first.data();
    final reservationDate = (firstData['reservation_date'] is Timestamp)
        ? (firstData['reservation_date'] as Timestamp).toDate()
        : _selectedDate;
    final isIssued = firstData['is_issued'] == true;
    final status = (firstData['status'] ?? 'active').toString();

    final validation = _mealReservationService.validateCancellationWindow(
      reservationDate: reservationDate,
      isIssued: isIssued,
      status: status,
    );

    if (!validation.isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation.message),
        ),
      );
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No authenticated user found.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      for (final doc in docs) {
        await _mealReservationService.cancelReservation(
          reservationId: doc.id,
          cancelledByUid: authUser.uid,
          cancelledByRole: 'employee',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_mealLabel(mealType)} reservation cancelled.'),
        ),
      );

      await _loadScreenData(forceRefresh: true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancellation failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildDateSelectorCard() {
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
                  'Today Menu Reservation',
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
                  'Reservation Date: ${_formatDate(_selectedDate)}',
                  style: const TextStyle(fontSize: 14),
                ),
                if (_dailyMenu != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Cycle: ${_dailyMenu!.cycleName} • ${_dailyMenu!.weekday}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Select Date'),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _loadScreenData(forceRefresh: true),
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

  Widget _buildIdentityCard() {
    final identity = _identityResult;
    final employeeNumber = identity?.employeeNumber?.trim() ?? '';
    final employeeName = (_userProfile?.employeeName ?? '').trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Identity & Booking Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _SummaryRow(
              label: 'Employee Name',
              value: employeeName.isEmpty ? '—' : employeeName,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Employee Number',
              value: employeeNumber.isEmpty ? '—' : employeeNumber,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Profile Role',
              value: _userProfile?.roleLabel ?? '—',
            ),
            if (_identityWarning != null) ...[
              const SizedBox(height: 12),
              Text(
                _identityWarning!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(String mealType, ResolvedMealOption option) {
    final draft = _draftFor(mealType, option.optionKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              option.optionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(_buildItemsSummary(option)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuantityEditor(
                    label: 'Dine In',
                    value: draft.dineInQuantity,
                    onChanged: (value) {
                      _setDraftQuantity(
                        mealType: mealType,
                        optionKey: option.optionKey,
                        diningMode: 'dine_in',
                        quantity: value,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuantityEditor(
                    label: 'Takeaway',
                    value: draft.takeawayQuantity,
                    onChanged: (value) {
                      _setDraftQuantity(
                        mealType: mealType,
                        optionKey: option.optionKey,
                        diningMode: 'takeaway',
                        quantity: value,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingReservationsSection(String mealType) {
    final docs = _existingReservationsByMeal[mealType]!;

    if (docs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: docs.map((doc) {
        final data = doc.data();
        final option = (data['option_label'] ?? '').toString();
        final mode = (data['dining_mode'] ?? '').toString();
        final qty = (data['quantity'] ?? 0).toString();
        final status = (data['status'] ?? '').toString();
        final issued = data['is_issued'] == true;
        final createdAt = _formatDateTime(data['created_at']);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: issued ? Colors.green.withValues(alpha: 0.06) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.isEmpty ? 'Reserved option' : option,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Dining Mode: ${_modeLabel(mode)}'),
                const SizedBox(height: 4),
                Text('Quantity: $qty'),
                const SizedBox(height: 4),
                Text('Status: ${issued ? 'Issued' : status}'),
                const SizedBox(height: 4),
                Text('Created At: $createdAt'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMealActionSection({
    required String mealType,
    required bool hasExistingReservation,
    required bool canBook,
    required bool canCancel,
    required bool hasOptions,
  }) {
    final totalDraftQty = _totalDraftQuantityForMeal(mealType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasExistingReservation)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving || !canCancel
                      ? null
                      : () => _cancelMeal(mealType),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Reservation'),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving || !canBook || !hasOptions
                      ? null
                      : () => _saveMeal(mealType),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    totalDraftQty > 0
                        ? 'Save Reservation ($totalDraftQty)'
                        : 'Save Reservation',
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMealCard(String mealType) {
    final options = _optionsForMeal(mealType);
    final hasExistingReservation =
        _existingReservationsByMeal[mealType]!.isNotEmpty;

    final bookingValidation = _mealReservationService.validateBookingWindow(
      mealType: mealType,
      reservationDate: _selectedDate,
    );

    CancellationValidationResult cancellationValidation =
        const CancellationValidationResult(
      isAllowed: false,
      message: 'No reservation found.',
    );

    if (hasExistingReservation) {
      final firstData = _existingReservationsByMeal[mealType]!.first.data();
      final reservationDate = (firstData['reservation_date'] is Timestamp)
          ? (firstData['reservation_date'] as Timestamp).toDate()
          : _selectedDate;
      final isIssued = firstData['is_issued'] == true;
      final status = (firstData['status'] ?? 'active').toString();

      cancellationValidation =
          _mealReservationService.validateCancellationWindow(
        reservationDate: reservationDate,
        isIssued: isIssued,
        status: status,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  mealType == 'breakfast'
                      ? Icons.free_breakfast_outlined
                      : mealType == 'lunch'
                          ? Icons.lunch_dining_outlined
                          : Icons.dinner_dining_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _mealLabel(mealType),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hasExistingReservation)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Reserved',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (!hasExistingReservation && !bookingValidation.isAllowed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  bookingValidation.message,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (hasExistingReservation &&
                !cancellationValidation.isAllowed &&
                cancellationValidation.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  cancellationValidation.message,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            if (hasExistingReservation)
              _buildExistingReservationsSection(mealType)
            else if (options.isEmpty)
              const Text('No menu available for this meal.')
            else
              ...options.map((option) => _buildOptionTile(mealType, option)),
            const SizedBox(height: 16),
            _buildMealActionSection(
              mealType: mealType,
              hasExistingReservation: hasExistingReservation,
              canBook: bookingValidation.isAllowed,
              canCancel: cancellationValidation.isAllowed,
              hasOptions: options.isNotEmpty,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Menu Load Error',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _loadScreenData(forceRefresh: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadScreenData(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDateSelectorCard(),
            const SizedBox(height: 12),
            _buildIdentityCard(),
            const SizedBox(height: 16),
            _buildMealCard('breakfast'),
            const SizedBox(height: 12),
            _buildMealCard('lunch'),
            const SizedBox(height: 12),
            _buildMealCard('dinner'),
          ],
        ),
      ),
    );
  }
}

class _MealSelectionDraft {
  final int dineInQuantity;
  final int takeawayQuantity;

  const _MealSelectionDraft({
    this.dineInQuantity = 0,
    this.takeawayQuantity = 0,
  });

  _MealSelectionDraft copyWith({
    int? dineInQuantity,
    int? takeawayQuantity,
  }) {
    return _MealSelectionDraft(
      dineInQuantity: dineInQuantity ?? this.dineInQuantity,
      takeawayQuantity: takeawayQuantity ?? this.takeawayQuantity,
    );
  }
}

class _QuantityEditor extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _QuantityEditor({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: value <= 0 ? null : () => onChanged(value - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      value.toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onChanged(value + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
