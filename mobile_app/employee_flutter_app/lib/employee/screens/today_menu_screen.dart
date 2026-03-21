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

  final Map<String, String> _selectedOptionByMeal = {};
  final Map<String, String> _selectedDiningModeByMeal = {
    'breakfast': 'dine_in',
    'lunch': 'dine_in',
    'dinner': 'dine_in',
  };

  final Map<String, DocumentSnapshot<Map<String, dynamic>>>
      _existingReservationDocs = {};

  @override
  void initState() {
    super.initState();

    _selectedDate = _normalizeDate(DateTime.now());

    _selectedDiningModeByMeal['breakfast'] = widget.initialDiningMode;
    _selectedDiningModeByMeal['lunch'] = widget.initialDiningMode;
    _selectedDiningModeByMeal['dinner'] = widget.initialDiningMode;

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
            'Employee linkage is incomplete. Menu can be viewed, but reservation save/update is disabled until users.employee_number and employees linkage is correct.';
      }

      final existingDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      if (identityResult.found &&
          identityResult.employeeNumber != null &&
          identityResult.employeeNumber!.trim().isNotEmpty) {
        final startOfDay = normalizedDate;
        final nextDay = startOfDay.add(const Duration(days: 1));

        final reservationsSnapshot = await _firestore
            .collection('meal_reservations')
            .where(
              'employee_number',
              isEqualTo: identityResult.employeeNumber!.trim(),
            )
            .where(
              'reservation_date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where(
              'reservation_date',
              isLessThan: Timestamp.fromDate(nextDay),
            )
            .get();

        for (final doc in reservationsSnapshot.docs) {
          final data = doc.data();
          final mealType =
              (data['meal_type'] ?? '').toString().trim().toLowerCase();
          if (mealType.isNotEmpty) {
            existingDocs[mealType] = doc;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _dailyMenu = menu;
        _userProfile = userProfile;
        _identityResult = identityResult;
        _existingReservationDocs
          ..clear()
          ..addAll(existingDocs);
        _identityWarning = identityWarning;

        _initializeSelectionStateFromMenu();
        _applyExistingReservationsToUi();

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

  void _initializeSelectionStateFromMenu() {
    final menu = _dailyMenu;
    if (menu == null) return;

    _initializeMealOptions('breakfast', menu.breakfastOptions);
    _initializeMealOptions('lunch', menu.lunchOptions);
    _initializeMealOptions('dinner', menu.dinnerOptions);
  }

  void _initializeMealOptions(
    String mealType,
    List<ResolvedMealOption> options,
  ) {
    if (options.isEmpty) return;

    _selectedOptionByMeal.putIfAbsent(mealType, () => options.first.optionKey);
    _selectedDiningModeByMeal.putIfAbsent(
      mealType,
      () => widget.initialDiningMode,
    );
  }

  void _applyExistingReservationsToUi() {
    for (final entry in _existingReservationDocs.entries) {
      final mealType = entry.key;
      final data = entry.value.data();
      if (data == null) continue;

      final notes = (data['notes'] ?? '').toString();
      final diningMode = (data['dining_mode'] ?? widget.initialDiningMode)
          .toString()
          .trim()
          .toLowerCase();

      final selectedKey = _extractSelectedOptionKeyFromNotes(notes);

      if (selectedKey != null && selectedKey.isNotEmpty) {
        _selectedOptionByMeal[mealType] = selectedKey;
      }

      if (diningMode == 'dine_in' || diningMode == 'takeaway') {
        _selectedDiningModeByMeal[mealType] = diningMode;
      }
    }
  }

  String? _extractSelectedOptionKeyFromNotes(String notes) {
    const prefix = 'Selected option: ';
    if (!notes.startsWith(prefix)) return null;
    return notes.substring(prefix.length).trim();
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
      _existingReservationDocs.clear();
      _selectedOptionByMeal.clear();
      _selectedDiningModeByMeal['breakfast'] = widget.initialDiningMode;
      _selectedDiningModeByMeal['lunch'] = widget.initialDiningMode;
      _selectedDiningModeByMeal['dinner'] = widget.initialDiningMode;
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

    final validation = _bookingValidationForMeal(mealType);
    if (!validation.isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation.message)),
      );
      return;
    }

    final selectedOptionKey = _selectedOptionByMeal[mealType];
    if (selectedOptionKey == null || selectedOptionKey.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a ${_mealLabel(mealType)} option first.'),
        ),
      );
      return;
    }

    final selectedDiningMode =
        _selectedDiningModeByMeal[mealType] ?? widget.initialDiningMode;
    final options = _optionsForMeal(mealType);

    final selectedOption = options.cast<ResolvedMealOption?>().firstWhere(
          (option) => option?.optionKey == selectedOptionKey,
          orElse: () => null,
        );

    if (selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected option could not be resolved.'),
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

    final existingDoc = _existingReservationDocs[mealType];
    final notes = 'Selected option: ${selectedOption.optionKey}';

    setState(() {
      _isSaving = true;
    });

    try {
      if (existingDoc == null) {
        await _mealReservationService.createReservation(
          employeeNumber: employeeNumber,
          employeeName: employeeName,
          reservationDate: _selectedDate,
          mealType: mealType,
          bookingType: 'self',
          diningMode: selectedDiningMode,
          quantity: 1,
          createdByUid: authUser.uid,
          createdByRole: _userProfile?.roleLabel ?? 'employee',
          notes: notes,
        );
      } else {
        final validation = _bookingValidationForMeal(mealType);
        if (!validation.isAllowed) {
          throw StateError(validation.message);
        }

        await _firestore
            .collection('meal_reservations')
            .doc(existingDoc.id)
            .update({
          'reservation_date': Timestamp.fromDate(_selectedDate),
          'dining_mode': selectedDiningMode,
          'notes': notes,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

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
            const SizedBox(height: 6),
            Text(
              'Default Screen Mode: ${widget.initialDiningMode == 'takeaway' ? 'Takeaway' : 'Dine In'}',
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

  Widget _buildOptionTile(
    String mealType,
    ResolvedMealOption option,
    String? selectedOptionKey,
  ) {
    final isSelected = selectedOptionKey == option.optionKey;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: !_canSaveReservation
            ? null
            : () {
                setState(() {
                  _selectedOptionByMeal[mealType] = option.optionKey;
                });
              },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.optionLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealCard(String mealType) {
    final options = _optionsForMeal(mealType);
    final existingDoc = _existingReservationDocs[mealType];
    final existingData = existingDoc?.data();
    final selectedOptionKey = _selectedOptionByMeal[mealType];
    final selectedDiningMode =
        _selectedDiningModeByMeal[mealType] ?? widget.initialDiningMode;
    final validation = _bookingValidationForMeal(mealType);

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
              'Booking Status: ${validation.message}',
              style: TextStyle(
                color: validation.isAllowed
                    ? Colors.green
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            if (existingData != null) ...[
              Text(
                'Existing reservation found for selected date.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (options.isEmpty)
              const Text('No menu options available.')
            else
              ...options.map(
                (option) => _buildOptionTile(
                  mealType,
                  option,
                  selectedOptionKey,
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Dining Mode',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Dine In'),
                  selected: selectedDiningMode == 'dine_in',
                  onSelected: !_canSaveReservation
                      ? null
                      : (selected) {
                          if (!selected) return;
                          setState(() {
                            _selectedDiningModeByMeal[mealType] = 'dine_in';
                          });
                        },
                ),
                ChoiceChip(
                  label: const Text('Takeaway'),
                  selected: selectedDiningMode == 'takeaway',
                  onSelected: !_canSaveReservation
                      ? null
                      : (selected) {
                          if (!selected) return;
                          setState(() {
                            _selectedDiningModeByMeal[mealType] = 'takeaway';
                          });
                        },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isSaving ||
                        options.isEmpty ||
                        !_canSaveReservation ||
                        !validation.isAllowed)
                    ? null
                    : () => _saveMealReservation(mealType),
                icon: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  existingData == null
                      ? 'Save Reservation'
                      : 'Update Reservation',
                ),
              ),
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
