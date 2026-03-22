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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> _loadScreenData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _identityWarning = null;
    });

    try {
      final normalizedDate = _normalizeDate(_selectedDate);

      final menu =
          await _menuResolverService.getBookingMenuForDate(normalizedDate);

      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        throw Exception('No authenticated user found.');
      }

      final userProfile = await _userProfileService.resolveCurrentUserProfile(
        authUid: authUser.uid,
      );

      final identityResult =
          await _employeeIdentityService.resolveByAuthUid(authUser.uid);

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
        final startOfDay = normalizedDate;

        final reservationsSnapshot = await _firestore
            .collection('meal_reservations')
            .where(
              'employee_number',
              isEqualTo: identityResult.employeeNumber!.trim(),
            )
            .get();

        for (final doc in reservationsSnapshot.docs) {
          final data = doc.data();

          final reservationTimestamp = data['reservation_date'];
          if (reservationTimestamp is! Timestamp) {
            continue;
          }

          final reservationDate = reservationTimestamp.toDate();
          final normalizedReservationDate = DateTime(
            reservationDate.year,
            reservationDate.month,
            reservationDate.day,
          );

          if (normalizedReservationDate != startOfDay) {
            continue;
          }

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

        _initializeDraftStateFromMenu();
        _resetAllEditModes();
        _prefillDraftsFromExistingReservations();

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load menu: $e';
        _isLoading = false;
      });
    }
  }

  void _resetAllEditModes() {
    _isEditModeByMeal['breakfast'] = false;
    _isEditModeByMeal['lunch'] = false;
    _isEditModeByMeal['dinner'] = false;
  }

  void _initializeDraftStateFromMenu() {
    _initializeMealDrafts('breakfast', _optionsForMeal('breakfast'));
    _initializeMealDrafts('lunch', _optionsForMeal('lunch'));
    _initializeMealDrafts('dinner', _optionsForMeal('dinner'));
  }

  void _initializeMealDrafts(
    String mealType,
    List<ResolvedMealOption> options,
  ) {
    final drafts = _draftsByMeal[mealType]!;
    drafts.clear();

    for (final option in options) {
      drafts[option.optionKey] = const _MealSelectionDraft();
    }
  }

  void _prefillDraftsFromExistingReservations() {
    for (final mealType in ['breakfast', 'lunch', 'dinner']) {
      final docs = _existingReservationsByMeal[mealType] ?? const [];
      final drafts = _draftsByMeal[mealType];

      if (drafts == null || docs.isEmpty) {
        continue;
      }

      for (final doc in docs) {
        final data = doc.data();
        final optionKey = (data['menu_option_key'] ?? '').toString().trim();
        final diningMode = (data['dining_mode'] ?? '').toString().trim();
        final quantity = (data['quantity'] ?? 0) is int
            ? data['quantity'] as int
            : int.tryParse((data['quantity'] ?? '0').toString()) ?? 0;

        if (optionKey.isEmpty || quantity <= 0 || !drafts.containsKey(optionKey)) {
          continue;
        }

        final current = drafts[optionKey] ?? const _MealSelectionDraft();

        if (diningMode == 'takeaway') {
          drafts[optionKey] = current.copyWith(takeawayQuantity: quantity);
        } else {
          drafts[optionKey] = current.copyWith(dineInQuantity: quantity);
        }
      }
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

  bool get _canSaveReservation {
    return _identityResult != null &&
        _identityResult!.found &&
        (_identityResult!.employeeNumber ?? '').trim().isNotEmpty &&
        _userProfile != null &&
        _userProfile!.isActive;
  }

  bool get _isPastDate {
    final today = _normalizeDate(DateTime.now());
    return _selectedDate.isBefore(today);
  }

  bool get _isFutureDate {
    final today = _normalizeDate(DateTime.now());
    return _selectedDate.isAfter(today);
  }

  String get _selectedDateContextLabel {
    if (_isPastDate) return 'Past Date';
    if (_isFutureDate) return 'Future Date';
    return 'Today';
  }

  ReservationValidationResult _bookingValidationForMeal(String mealType) {
    return _mealReservationService.validateReservationRequest(
      reservationDate: _selectedDate,
      mealType: mealType,
    );
  }

  ReservationValidationResult _cancellationValidationForMeal(String mealType) {
    return _mealReservationService.validateCancellationRequest(
      reservationDate: _selectedDate,
      mealType: mealType,
    );
  }

  String _cutoffDisplayForMeal(String mealType) {
    return _mealReservationService.getMealCutoffDisplay(
      reservationDate: _selectedDate,
      mealType: mealType,
    );
  }

  Future<void> _changeSelectedDate(DateTime newDate) async {
    final normalizedDate = _normalizeDate(newDate);

    setState(() {
      _selectedDate = normalizedDate;
      _dailyMenu = null;
      _draftsByMeal['breakfast']!.clear();
      _draftsByMeal['lunch']!.clear();
      _draftsByMeal['dinner']!.clear();
      _existingReservationsByMeal['breakfast']!.clear();
      _existingReservationsByMeal['lunch']!.clear();
      _existingReservationsByMeal['dinner']!.clear();
      _resetAllEditModes();
    });

    await _loadScreenData();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day).subtract(
      const Duration(days: 7),
    );
    final lastDate = DateTime(now.year, now.month, now.day).add(
      const Duration(days: 30),
    );

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate == null) return;
    await _changeSelectedDate(pickedDate);
  }

  Future<void> _goToPreviousDate() async {
    await _changeSelectedDate(_selectedDate.subtract(const Duration(days: 1)));
  }

  Future<void> _goToNextDate() async {
    await _changeSelectedDate(_selectedDate.add(const Duration(days: 1)));
  }

  int _mealDraftTotalLines(String mealType) {
    int count = 0;
    final drafts =
        _draftsByMeal[mealType] ?? const <String, _MealSelectionDraft>{};

    for (final draft in drafts.values) {
      if (draft.dineInQuantity > 0) count++;
      if (draft.takeawayQuantity > 0) count++;
    }

    return count;
  }

  int _mealDraftTotalQuantity(String mealType) {
    int total = 0;
    final drafts =
        _draftsByMeal[mealType] ?? const <String, _MealSelectionDraft>{};

    for (final draft in drafts.values) {
      total += draft.dineInQuantity + draft.takeawayQuantity;
    }

    return total;
  }

  bool _hasExistingReservationForMeal(String mealType) {
    return (_existingReservationsByMeal[mealType] ?? const []).isNotEmpty;
  }

  bool _isMealInEditMode(String mealType) {
    return _isEditModeByMeal[mealType] == true;
  }

  void _enterEditMode(String mealType) {
    if (_isSaving) return;

    setState(() {
      _isEditModeByMeal[mealType] = true;
    });
  }

  void _exitEditMode(String mealType) {
    if (_isSaving) return;

    setState(() {
      _isEditModeByMeal[mealType] = false;
      _initializeMealDrafts(mealType, _optionsForMeal(mealType));
      _prefillMealDraftFromExistingReservations(mealType);
    });
  }

  void _prefillMealDraftFromExistingReservations(String mealType) {
    final docs = _existingReservationsByMeal[mealType] ?? const [];
    final drafts = _draftsByMeal[mealType];
    if (drafts == null) return;

    for (final optionKey in drafts.keys.toList()) {
      drafts[optionKey] = const _MealSelectionDraft();
    }

    for (final doc in docs) {
      final data = doc.data();
      final optionKey = (data['menu_option_key'] ?? '').toString().trim();
      final diningMode = (data['dining_mode'] ?? '').toString().trim();
      final quantity = (data['quantity'] ?? 0) is int
          ? data['quantity'] as int
          : int.tryParse((data['quantity'] ?? '0').toString()) ?? 0;

      if (optionKey.isEmpty || quantity <= 0 || !drafts.containsKey(optionKey)) {
        continue;
      }

      final current = drafts[optionKey] ?? const _MealSelectionDraft();

      if (diningMode == 'takeaway') {
        drafts[optionKey] = current.copyWith(takeawayQuantity: quantity);
      } else {
        drafts[optionKey] = current.copyWith(dineInQuantity: quantity);
      }
    }
  }

  void _changeDraftQuantity({
    required String mealType,
    required String optionKey,
    required String diningMode,
    required int delta,
  }) {
    if (!_canSaveReservation || _isSaving) {
      return;
    }

    final hasExisting = _hasExistingReservationForMeal(mealType);
    final isEditMode = _isMealInEditMode(mealType);

    if (hasExisting && !isEditMode) {
      return;
    }

    final drafts = _draftsByMeal[mealType];
    if (drafts == null || !drafts.containsKey(optionKey)) {
      return;
    }

    final current = drafts[optionKey]!;
    final currentQty = diningMode == 'dine_in'
        ? current.dineInQuantity
        : current.takeawayQuantity;
    final newQty = currentQty + delta;

    if (newQty < 0) {
      return;
    }

    setState(() {
      if (diningMode == 'dine_in') {
        drafts[optionKey] = current.copyWith(dineInQuantity: newQty);
      } else {
        drafts[optionKey] = current.copyWith(takeawayQuantity: newQty);
      }
    });
  }

  List<ReservationLineInput> _buildReservationLinesForMeal(
    String mealType,
  ) {
    final options = _optionsForMeal(mealType);
    final drafts =
        _draftsByMeal[mealType] ?? const <String, _MealSelectionDraft>{};

    final lines = <ReservationLineInput>[];

    for (final option in options) {
      final draft = drafts[option.optionKey];
      if (draft == null) continue;

      if (draft.dineInQuantity > 0) {
        lines.add(
          ReservationLineInput(
            menuOptionKey: option.optionKey,
            optionLabel: option.optionLabel,
            diningMode: 'dine_in',
            quantity: draft.dineInQuantity,
          ),
        );
      }

      if (draft.takeawayQuantity > 0) {
        lines.add(
          ReservationLineInput(
            menuOptionKey: option.optionKey,
            optionLabel: option.optionLabel,
            diningMode: 'takeaway',
            quantity: draft.takeawayQuantity,
          ),
        );
      }
    }

    return lines;
  }

  Future<void> _saveMealReservation(String mealType) async {
    if (!_canSaveReservation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reservation save is disabled until employee linkage is complete and account is active.',
          ),
        ),
      );
      return;
    }

    if (_hasExistingReservationForMeal(mealType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_mealLabel(mealType)} already has an active reservation. Use Edit or Cancel.',
          ),
        ),
      );
      return;
    }

    final validation = _bookingValidationForMeal(mealType);
    if (!validation.isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation.message)),
      );
      return;
    }

    final lines = _buildReservationLinesForMeal(mealType);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add at least one ${_mealLabel(mealType)} quantity before saving.',
          ),
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

    final employeeNumber = _identityResult!.employeeNumber!.trim();
    final employeeName = (_identityResult!.employeeData?['name'] ??
            _identityResult!.employeeData?['employee_name'] ??
            _identityResult!.userData?['employee_name'] ??
            _userProfile?.employeeName ??
            '')
        .toString()
        .trim();

    if (employeeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee name could not be resolved.'),
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
        lines: lines,
        createdByUid: authUser.uid,
        createdByRole: _userProfile?.roleLabel ?? 'employee',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_mealLabel(mealType)} reservation saved successfully for ${_formatDate(_selectedDate)}.',
          ),
        ),
      );

      await _loadScreenData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed to save ${_mealLabel(mealType)} reservation: $e'),
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

  Future<void> _updateMealReservation(String mealType) async {
    if (!_canSaveReservation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reservation update is disabled until employee linkage is complete and account is active.',
          ),
        ),
      );
      return;
    }

    if (!_hasExistingReservationForMeal(mealType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No existing ${_mealLabel(mealType)} reservation found to edit.',
          ),
        ),
      );
      return;
    }

    final validation = _bookingValidationForMeal(mealType);
    if (!validation.isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation.message)),
      );
      return;
    }

    final lines = _buildReservationLinesForMeal(mealType);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'At least one line is required. Use Cancel Reservation if you want to remove the whole booking.',
          ),
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

    final employeeNumber = _identityResult!.employeeNumber!.trim();
    final employeeName = (_identityResult!.employeeData?['name'] ??
            _identityResult!.employeeData?['employee_name'] ??
            _identityResult!.userData?['employee_name'] ??
            _userProfile?.employeeName ??
            '')
        .toString()
        .trim();

    if (employeeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee name could not be resolved.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _mealReservationService.replaceReservationGroupForEmployeeDateMeal(
        employeeNumber: employeeNumber,
        employeeName: employeeName,
        reservationDate: _selectedDate,
        mealType: mealType,
        lines: lines,
        updatedByUid: authUser.uid,
        updatedByRole: _userProfile?.roleLabel ?? 'employee',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_mealLabel(mealType)} reservation updated successfully for ${_formatDate(_selectedDate)}.',
          ),
        ),
      );

      await _loadScreenData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed to update ${_mealLabel(mealType)} reservation: $e'),
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

  Future<void> _cancelMealReservation(String mealType) async {
    if (!_canSaveReservation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reservation cancellation is disabled until employee linkage is complete and account is active.',
          ),
        ),
      );
      return;
    }

    if (!_hasExistingReservationForMeal(mealType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No existing ${_mealLabel(mealType)} reservation found to cancel.',
          ),
        ),
      );
      return;
    }

    final validation = _cancellationValidationForMeal(mealType);
    if (!validation.isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation.message)),
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

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Cancel ${_mealLabel(mealType)} Reservation'),
            content: Text(
              'Are you sure you want to cancel the full ${_mealLabel(mealType).toLowerCase()} reservation for ${_formatDate(_selectedDate)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _mealReservationService.cancelActiveReservationsForEmployeeDateMeal(
        employeeNumber: _identityResult!.employeeNumber!.trim(),
        reservationDate: _selectedDate,
        mealType: mealType,
        cancelledByUid: authUser.uid,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_mealLabel(mealType)} reservation cancelled successfully.',
          ),
        ),
      );

      await _loadScreenData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed to cancel ${_mealLabel(mealType)} reservation: $e'),
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  Widget _buildDateSelectorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reservation Date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('Selected Date: ${_formatDate(_selectedDate)}'),
            const SizedBox(height: 6),
            Text(
              'Date Context: $_selectedDateContextLabel',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _isPastDate
                    ? Theme.of(context).colorScheme.error
                    : Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _goToPreviousDate,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Pick Date'),
                ),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _goToNextDate,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard() {
    final profile = _userProfile;
    final identity = _identityResult;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Booking Context',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text('Logged in as: ${widget.userEmail}'),
            const SizedBox(height: 6),
            Text('Date: ${_formatDate(_selectedDate)}'),
            const SizedBox(height: 6),
            Text('Role: ${profile?.roleLabel ?? 'unknown'}'),
            const SizedBox(height: 6),
            Text(
              'Employee Number: ${identity?.employeeNumber?.trim().isNotEmpty == true ? identity!.employeeNumber : 'Not linked'}',
            ),
            const SizedBox(height: 6),
            Text(
              'Link Status: ${identity?.found == true ? 'Ready for reservation' : 'Link incomplete'}',
            ),
            if (_identityWarning != null) ...[
              const SizedBox(height: 12),
              Text(
                _identityWarning!,
                style: const TextStyle(color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityAdjuster({
    required String mealType,
    required String optionKey,
    required String diningMode,
    required int quantity,
    required String label,
  }) {
    final hasExistingReservation = _hasExistingReservationForMeal(mealType);
    final isEditMode = _isMealInEditMode(mealType);

    final isReadOnlyBecauseExisting =
        hasExistingReservation && !isEditMode;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: (!_canSaveReservation ||
                    _isSaving ||
                    isReadOnlyBecauseExisting)
                ? null
                : () => _changeDraftQuantity(
                      mealType: mealType,
                      optionKey: optionKey,
                      diningMode: diningMode,
                      delta: -1,
                    ),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            quantity.toString(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: (!_canSaveReservation ||
                    _isSaving ||
                    isReadOnlyBecauseExisting)
                ? null
                : () => _changeDraftQuantity(
                      mealType: mealType,
                      optionKey: optionKey,
                      diningMode: diningMode,
                      delta: 1,
                    ),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    String mealType,
    ResolvedMealOption option,
  ) {
    final draft = _draftsByMeal[mealType]?[option.optionKey] ??
        const _MealSelectionDraft();

    final isSelected = draft.dineInQuantity > 0 || draft.takeawayQuantity > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              option.optionLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(_buildItemsSummary(option)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(option.optionKey),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            _buildQuantityAdjuster(
              mealType: mealType,
              optionKey: option.optionKey,
              diningMode: 'dine_in',
              quantity: draft.dineInQuantity,
              label: 'Dine In',
            ),
            _buildQuantityAdjuster(
              mealType: mealType,
              optionKey: option.optionKey,
              diningMode: 'takeaway',
              quantity: draft.takeawayQuantity,
              label: 'Takeaway',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingReservationSummary(String mealType) {
    final existingDocs = _existingReservationsByMeal[mealType] ?? const [];
    final isEditMode = _isMealInEditMode(mealType);

    if (existingDocs.isEmpty) {
      return const SizedBox.shrink();
    }

    final summaryLines = <String>[];

    for (final doc in existingDocs) {
      final data = doc.data();
      final optionLabel =
          (data['option_label'] ?? '').toString().trim().isNotEmpty
              ? (data['option_label'] ?? '').toString().trim()
              : (data['menu_option_key'] ?? 'Unknown option').toString().trim();

      final diningMode = (data['dining_mode'] ?? '').toString().trim();
      final quantity = (data['quantity'] ?? 0) is int
          ? data['quantity'] as int
          : int.tryParse((data['quantity'] ?? '0').toString()) ?? 0;
      final status = (data['status'] ?? '').toString().trim();

      final diningModeLabel =
          diningMode == 'takeaway' ? 'Takeaway' : 'Dine In';

      summaryLines
          .add('$optionLabel • $diningModeLabel • Qty $quantity • $status');
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEditMode
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditMode
                ? 'Edit mode is active for this meal'
                : 'Existing reservation already saved for selected date',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isEditMode
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          ...summaryLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEditMode
                ? 'Adjust quantities below, then press Update Reservation.'
                : 'You can edit or cancel this reservation.',
          ),
        ],
      ),
    );
  }

  Widget _buildMealActionSection({
    required String mealType,
    required bool hasExistingReservation,
    required bool canBook,
    required bool canCancel,
    required bool hasOptions,
  }) {
    final isEditMode = _isMealInEditMode(mealType);

    if (!hasExistingReservation) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: (_isSaving ||
                  !hasOptions ||
                  !_canSaveReservation ||
                  !canBook)
              ? null
              : () => _saveMealReservation(mealType),
          icon: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save Reservation'),
        ),
      );
    }

    if (!isEditMode) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _enterEditMode(mealType),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Reservation'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isSaving || !_canSaveReservation || !canCancel)
                  ? null
                  : () => _cancelMealReservation(mealType),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Reservation'),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isSaving ||
                    !hasOptions ||
                    !_canSaveReservation ||
                    !canBook)
                ? null
                : () => _updateMealReservation(mealType),
            icon: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_as_outlined),
            label: const Text('Update Reservation'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _exitEditMode(mealType),
            icon: const Icon(Icons.close),
            label: const Text('Cancel Edit'),
          ),
        ),
      ],
    );
  }

  Widget _buildMealCard(String mealType) {
    final options = _optionsForMeal(mealType);
    final bookingValidation = _bookingValidationForMeal(mealType);
    final cancellationValidation = _cancellationValidationForMeal(mealType);
    final hasExistingReservation = _hasExistingReservationForMeal(mealType);
    final draftLineCount = _mealDraftTotalLines(mealType);
    final draftTotalQuantity = _mealDraftTotalQuantity(mealType);
    final isEditMode = _isMealInEditMode(mealType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _mealLabel(mealType),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Cutoff Time: ${_cutoffDisplayForMeal(mealType)}'),
            const SizedBox(height: 6),
            Text(
              'Booking Status: ${bookingValidation.message}',
              style: TextStyle(
                color: bookingValidation.isAllowed
                    ? Colors.green
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasExistingReservation) ...[
              const SizedBox(height: 6),
              Text(
                'Cancellation Status: ${cancellationValidation.message}',
                style: TextStyle(
                  color: cancellationValidation.isAllowed
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Draft Summary: $draftLineCount line(s), total quantity $draftTotalQuantity',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (hasExistingReservation && isEditMode) ...[
              const SizedBox(height: 6),
              const Text(
                'Edit Mode: active',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildExistingReservationSummary(mealType),
            if (options.isEmpty)
              const Text('No menu options available.')
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
                      onPressed: _loadScreenData,
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
        onRefresh: _loadScreenData,
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
