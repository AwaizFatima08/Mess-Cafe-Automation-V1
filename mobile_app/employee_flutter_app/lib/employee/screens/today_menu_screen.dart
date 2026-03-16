import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../admin/services/menu_resolver_service.dart';
import '../../core/constants/reservation_constants.dart';
import '../../models/meal_booking_request.dart';
import '../../models/meal_option_selection.dart';
import '../../models/meal_reservation.dart';
import '../../services/employee_identity_service.dart';
import '../../services/meal_reservation_service.dart';
import '../../services/user_profile_service.dart';

class TodayMenuScreen extends StatefulWidget {
  final String userEmail;

  const TodayMenuScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<TodayMenuScreen> createState() => _TodayMenuScreenState();
}

class _TodayMenuScreenState extends State<TodayMenuScreen> {
  final MenuResolverService _menuResolverService = MenuResolverService();
  final MealReservationService _mealReservationService = MealReservationService();
  final EmployeeIdentityService _employeeIdentityService =
      EmployeeIdentityService();
  final UserProfileService _userProfileService = UserProfileService();

  final DateTime _selectedDate = DateTime.now();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _identityWarning;

  dynamic _dailyMenu;
  AppUserProfile? _userProfile;
  EmployeeIdentity? _employeeIdentity;

  MealReservation? _existingBreakfastReservation;
  MealReservation? _existingLunchReservation;
  MealReservation? _existingDinnerReservation;

  final Map<String, bool> _dineInSelections = {};
  final Map<String, bool> _takeawaySelections = {};
  final Map<String, int> _quantities = {};

  @override
  void initState() {
    super.initState();
    _loadScreenData();
  }

  Future<void> _loadScreenData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _identityWarning = null;
    });

    try {
      final menu =
          await _menuResolverService.getBookingMenuForDate(_selectedDate);

      final authUser = FirebaseAuth.instance.currentUser;
      final authUid = authUser?.uid;

      final userProfile = await _userProfileService.resolveCurrentUserProfile(
        userEmail: widget.userEmail,
        authUid: authUid,
      );

      EmployeeIdentity? identity;
      String? identityWarning;

      if (userProfile != null && userProfile.hasEmployeeLink) {
        identity = EmployeeIdentity(
          documentId: userProfile.documentId,
          employeeNumber: userProfile.employeeNumber,
          name: userProfile.employeeName,
          prefix: '',
          department: '',
          designation: '',
          userRole: userProfile.role.name,
        );

        final enrichedIdentity =
            await _employeeIdentityService.resolveForCurrentUser(
          userEmail: widget.userEmail,
          authUid: authUid,
        );

        if (enrichedIdentity != null &&
            enrichedIdentity.employeeNumber.trim() ==
                userProfile.employeeNumber.trim()) {
          identity = enrichedIdentity;
        }
      } else {
        final fallbackIdentity =
            await _employeeIdentityService.resolveForCurrentUser(
          userEmail: widget.userEmail,
          authUid: authUid,
        );

        if (fallbackIdentity != null &&
            fallbackIdentity.employeeNumber.trim().isNotEmpty) {
          identity = fallbackIdentity;
          identityWarning =
              'Employee identity was resolved from employees collection fallback. Link this user in the users collection for cleaner role and identity management.';
        } else {
          identityWarning =
              'Employee profile could not be matched from users/employees collections. Menu can be viewed, but reservation save/update is disabled until login mapping is configured.';
        }
      }

      MealReservation? breakfastReservation;
      MealReservation? lunchReservation;
      MealReservation? dinnerReservation;

      if (identity != null && identity.employeeNumber.trim().isNotEmpty) {
        final reservationResults = await Future.wait<dynamic>([
          _mealReservationService.getEmployeeReservationForMeal(
            employeeNumber: identity.employeeNumber,
            reservationDate: _selectedDate,
            mealType: ReservationConstants.breakfast,
          ),
          _mealReservationService.getEmployeeReservationForMeal(
            employeeNumber: identity.employeeNumber,
            reservationDate: _selectedDate,
            mealType: ReservationConstants.lunch,
          ),
          _mealReservationService.getEmployeeReservationForMeal(
            employeeNumber: identity.employeeNumber,
            reservationDate: _selectedDate,
            mealType: ReservationConstants.dinner,
          ),
        ]);

        breakfastReservation = reservationResults[0] as MealReservation?;
        lunchReservation = reservationResults[1] as MealReservation?;
        dinnerReservation = reservationResults[2] as MealReservation?;
      }

      if (!mounted) return;

      setState(() {
        _dailyMenu = menu;
        _userProfile = userProfile;
        _employeeIdentity = identity;
        _existingBreakfastReservation = breakfastReservation;
        _existingLunchReservation = lunchReservation;
        _existingDinnerReservation = dinnerReservation;
        _identityWarning = identityWarning;

        _initializeSelectionStateFromMenu();
        _applyExistingReservationsToUi();

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load today’s menu: $e';
        _isLoading = false;
      });
    }
  }

  void _initializeSelectionStateFromMenu() {
    _dineInSelections.clear();
    _takeawaySelections.clear();
    _quantities.clear();

    _initializeForOptions(_getBreakfastOptions());
    _initializeForOptions(_getLunchOptions());
    _initializeForOptions(_getDinnerOptions());
  }

  void _initializeForOptions(List<dynamic> options) {
    for (final option in options) {
      final key = _optionKey(option);
      _dineInSelections[key] = false;
      _takeawaySelections[key] = false;
      _quantities[key] = 1;
    }
  }

  void _applyExistingReservationsToUi() {
    _applyReservationToOptions(
      reservation: _existingBreakfastReservation,
      options: _getBreakfastOptions(),
    );
    _applyReservationToOptions(
      reservation: _existingLunchReservation,
      options: _getLunchOptions(),
    );
    _applyReservationToOptions(
      reservation: _existingDinnerReservation,
      options: _getDinnerOptions(),
    );
  }

  void _applyReservationToOptions({
    required MealReservation? reservation,
    required List<dynamic> options,
  }) {
    if (reservation == null) {
      return;
    }

    for (final selectedOption in reservation.selectedOptions) {
      final matchedOption = _findOptionBySavedSelection(
        options: options,
        savedOption: selectedOption,
      );

      if (matchedOption == null) {
        continue;
      }

      final uiKey = _optionKey(matchedOption);

      _quantities[uiKey] =
          selectedOption.quantity <= 0 ? 1 : selectedOption.quantity;

      if (reservation.serviceMode == ReservationConstants.takeaway) {
        _takeawaySelections[uiKey] = true;
        _dineInSelections[uiKey] = false;
      } else {
        _dineInSelections[uiKey] = true;
        _takeawaySelections[uiKey] = false;
      }
    }
  }

  dynamic _findOptionBySavedSelection({
    required List<dynamic> options,
    required MealOptionSelection savedOption,
  }) {
    for (final option in options) {
      final optionKey = _optionKey(option).trim().toLowerCase();
      final optionTitle = _optionTitle(option).trim().toLowerCase();
      final savedKey = savedOption.optionKey.trim().toLowerCase();
      final savedLabel = savedOption.optionLabel.trim().toLowerCase();

      if (optionKey == savedKey || optionTitle == savedLabel) {
        return option;
      }
    }

    return null;
  }

  List<dynamic> _getBreakfastOptions() {
    final options = _dailyMenu?.breakfastOptions;
    return options is List ? options : <dynamic>[];
  }

  List<dynamic> _getLunchOptions() {
    final options = _dailyMenu?.lunchOptions;
    return options is List ? options : <dynamic>[];
  }

  List<dynamic> _getDinnerOptions() {
    final options = _dailyMenu?.dinnerOptions;
    return options is List ? options : <dynamic>[];
  }

  String _optionKey(dynamic option) {
    final id = option?.id;
    final key = option?.optionKey;
    final name = option?.name;
    final title = option?.title;

    if (id != null && id.toString().trim().isNotEmpty) {
      return id.toString();
    }

    if (key != null && key.toString().trim().isNotEmpty) {
      return key.toString();
    }

    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString();
    }

    if (title != null && title.toString().trim().isNotEmpty) {
      return title.toString();
    }

    return option.hashCode.toString();
  }

  String _optionTitle(dynamic option) {
    final label = option?.optionLabel;
    final name = option?.name;
    final title = option?.title;
    final itemName = option?.itemName;

    if (label != null && label.toString().trim().isNotEmpty) {
      return label.toString();
    }

    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString();
    }

    if (title != null && title.toString().trim().isNotEmpty) {
      return title.toString();
    }

    if (itemName != null && itemName.toString().trim().isNotEmpty) {
      return itemName.toString();
    }

    return 'Meal Option';
  }

  String _optionSubtitle(dynamic option) {
    final List<String> parts = [];

    final category = option?.category;
    final mealType = option?.mealType;
    final description = option?.description;

    if (category != null && category.toString().trim().isNotEmpty) {
      parts.add(category.toString());
    }

    if (mealType != null && mealType.toString().trim().isNotEmpty) {
      parts.add(mealType.toString());
    }

    if (description != null && description.toString().trim().isNotEmpty) {
      parts.add(description.toString());
    }

    if (parts.isEmpty) {
      return 'Select dine-in or takeaway and set quantity.';
    }

    return parts.join(' • ');
  }

  bool _hasAnySelectionForOption(dynamic option) {
    final key = _optionKey(option);
    return (_dineInSelections[key] ?? false) ||
        (_takeawaySelections[key] ?? false);
  }

  int _selectedItemCount(List<dynamic> options) {
    return options.where(_hasAnySelectionForOption).length;
  }

  int _totalSelectedCount() {
    return _selectedItemCount(_getBreakfastOptions()) +
        _selectedItemCount(_getLunchOptions()) +
        _selectedItemCount(_getDinnerOptions());
  }

  int _existingReservationMealCount() {
    int count = 0;

    if (_existingBreakfastReservation != null) count++;
    if (_existingLunchReservation != null) count++;
    if (_existingDinnerReservation != null) count++;

    return count;
  }

  void _incrementQuantity(String key) {
    setState(() {
      final current = _quantities[key] ?? 1;
      _quantities[key] = current + 1;
    });
  }

  void _decrementQuantity(String key) {
    setState(() {
      final current = _quantities[key] ?? 1;
      if (current > 1) {
        _quantities[key] = current - 1;
      }
    });
  }

  Future<void> _refresh() async {
    await _loadScreenData();
  }

  String _formattedDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  MealBookingRequest? _buildMealBookingRequest({
    required String mealType,
    required List<dynamic> options,
  }) {
    final List<MealOptionSelection> selectedOptions = [];
    bool hasDineIn = false;
    bool hasTakeaway = false;

    for (final option in options) {
      final key = _optionKey(option);
      final label = _optionTitle(option);
      final quantity = _quantities[key] ?? 0;
      final isDineIn = _dineInSelections[key] ?? false;
      final isTakeaway = _takeawaySelections[key] ?? false;

      if (!isDineIn && !isTakeaway) {
        continue;
      }

      if (quantity <= 0) {
        continue;
      }

      if (isDineIn) {
        hasDineIn = true;
      }

      if (isTakeaway) {
        hasTakeaway = true;
      }

      selectedOptions.add(
        MealOptionSelection(
          optionKey: key,
          optionLabel: label,
          quantity: quantity,
        ),
      );
    }

    if (selectedOptions.isEmpty) {
      return null;
    }

    if (hasDineIn && hasTakeaway) {
      throw Exception(
        'A single $mealType booking cannot mix dine-in and takeaway options. Please choose only one service mode for $mealType.',
      );
    }

    final serviceMode = hasTakeaway
        ? ReservationConstants.takeaway
        : ReservationConstants.dineIn;

    return MealBookingRequest(
      reservationDate: _selectedDate,
      mealType: mealType,
      serviceMode: serviceMode,
      selectedOptions: selectedOptions,
    );
  }

  void _ensureEmployeeIdentityAvailable() {
    if (_employeeIdentity == null ||
        _employeeIdentity!.employeeNumber.trim().isEmpty) {
      throw Exception(
        'Employee identity could not be resolved from Firestore. Please link this login in the users collection.',
      );
    }
  }

  Future<void> _handleValidateBooking() async {
    try {
      _ensureEmployeeIdentityAvailable();

      final requests = <MealBookingRequest>[];

      final breakfastRequest = _buildMealBookingRequest(
        mealType: ReservationConstants.breakfast,
        options: _getBreakfastOptions(),
      );
      if (breakfastRequest != null) {
        requests.add(breakfastRequest);
      }

      final lunchRequest = _buildMealBookingRequest(
        mealType: ReservationConstants.lunch,
        options: _getLunchOptions(),
      );
      if (lunchRequest != null) {
        requests.add(lunchRequest);
      }

      final dinnerRequest = _buildMealBookingRequest(
        mealType: ReservationConstants.dinner,
        options: _getDinnerOptions(),
      );
      if (dinnerRequest != null) {
        requests.add(dinnerRequest);
      }

      if (requests.isEmpty) {
        throw Exception(
          'Please select at least one meal option before validation.',
        );
      }

      for (final request in requests) {
        final validationError =
            _mealReservationService.validateBookingRequest(request);
        if (validationError != null) {
          throw Exception(validationError);
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking validation successful.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Validation failed: $e'),
        ),
      );
    }
  }

  Future<void> _handleSaveBooking() async {
    setState(() {
      _isSaving = true;
    });

    try {
      _ensureEmployeeIdentityAvailable();

      final requests = <MealBookingRequest>[];

      final breakfastRequest = _buildMealBookingRequest(
        mealType: ReservationConstants.breakfast,
        options: _getBreakfastOptions(),
      );
      if (breakfastRequest != null) {
        requests.add(breakfastRequest);
      }

      final lunchRequest = _buildMealBookingRequest(
        mealType: ReservationConstants.lunch,
        options: _getLunchOptions(),
      );
      if (lunchRequest != null) {
        requests.add(lunchRequest);
      }

      final dinnerRequest = _buildMealBookingRequest(
        mealType: ReservationConstants.dinner,
        options: _getDinnerOptions(),
      );
      if (dinnerRequest != null) {
        requests.add(dinnerRequest);
      }

      if (requests.isEmpty) {
        throw Exception('Please select at least one meal option before saving.');
      }

      for (final request in requests) {
        final validationError =
            _mealReservationService.validateBookingRequest(request);

        if (validationError != null) {
          throw Exception(validationError);
        }

        final reservation =
            _mealReservationService.buildEmployeeReservationFromRequest(
          request: request,
          employeeNumber: _employeeIdentity!.employeeNumber,
          employeeName: _employeeIdentity!.name.isNotEmpty
              ? _employeeIdentity!.name
              : widget.userEmail,
          bookedByUserId: widget.userEmail,
          bookedByEmployeeNumber: _employeeIdentity!.employeeNumber,
        );

        await _mealReservationService.createOrUpdateEmployeeReservation(
          reservation,
        );
      }

      await _loadScreenData();

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal reservation saved successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reservation failed: $e'),
        ),
      );
    }
  }

  Widget _buildHeaderCard() {
    final existingCount = _existingReservationMealCount();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today’s Menu',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Booking date: ${_formattedDate(_selectedDate)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Logged in as: ${widget.userEmail}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_userProfile != null) ...[
              const SizedBox(height: 8),
              Text(
                'Access role: ${_userProfile!.role.name}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_employeeIdentity != null) ...[
              const SizedBox(height: 8),
              Text(
                'Employee: ${_employeeIdentity!.name.isNotEmpty ? _employeeIdentity!.name : "Unnamed Employee"}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Employee No: ${_employeeIdentity!.displayEmployeeCode}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_employeeIdentity!.department.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Department: ${_employeeIdentity!.department}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            if (_identityWarning != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_identityWarning!),
                    ),
                  ],
                ),
              ),
            ],
            if (existingCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Existing reservation loaded for $existingCount meal(s). You can review and update it.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection({
    required String title,
    required IconData icon,
    required List<dynamic> options,
    required MealReservation? existingReservation,
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
                if (existingReservation != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Saved'),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedItemCount(options)} selected',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            if (existingReservation != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Existing mode: ${existingReservation.serviceMode} • Total meals: ${existingReservation.totalMealCount}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (options.isEmpty)
              _buildEmptyState('No menu options available for $title.')
            else
              ...options.map(_buildOptionCard),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(dynamic option) {
    final key = _optionKey(option);
    final dineIn = _dineInSelections[key] ?? false;
    final takeaway = _takeawaySelections[key] ?? false;
    final quantity = _quantities[key] ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _optionTitle(option),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            _optionSubtitle(option),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilterChip(
                label: const Text('Dine In'),
                selected: dineIn,
                onSelected: (value) {
                  setState(() {
                    _dineInSelections[key] = value;
                    if (value) {
                      _takeawaySelections[key] = false;
                    }
                  });
                },
              ),
              FilterChip(
                label: const Text('Takeaway'),
                selected: takeaway,
                onSelected: (value) {
                  setState(() {
                    _takeawaySelections[key] = value;
                    if (value) {
                      _dineInSelections[key] = false;
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Quantity'),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _decrementQuantity(key),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$quantity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                onPressed: () => _incrementQuantity(key),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.restaurant_menu),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Total selected items: ${_totalSelectedCount()}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final identityResolved =
        _employeeIdentity != null &&
        _employeeIdentity!.employeeNumber.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!identityResolved) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Reservation actions are disabled until the logged-in user is linked to an employee record.',
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading || _isSaving || !identityResolved
                    ? null
                    : _handleValidateBooking,
                icon: const Icon(Icons.rule_folder_outlined),
                label: const Text('Validate Booking'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _isSaving || !identityResolved
                    ? null
                    : _handleSaveBooking,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Save Booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today’s Menu'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? ListView(
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
                                _errorMessage!,
                                style: Theme.of(context).textTheme.bodyMedium,
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
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 12),
                      _buildSummaryCard(),
                      const SizedBox(height: 12),
                      _buildMealSection(
                        title: 'Breakfast',
                        icon: Icons.free_breakfast_outlined,
                        options: _getBreakfastOptions(),
                        existingReservation: _existingBreakfastReservation,
                      ),
                      const SizedBox(height: 12),
                      _buildMealSection(
                        title: 'Lunch',
                        icon: Icons.lunch_dining_outlined,
                        options: _getLunchOptions(),
                        existingReservation: _existingLunchReservation,
                      ),
                      const SizedBox(height: 12),
                      _buildMealSection(
                        title: 'Dinner',
                        icon: Icons.dinner_dining_outlined,
                        options: _getDinnerOptions(),
                        existingReservation: _existingDinnerReservation,
                      ),
                      const SizedBox(height: 12),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                    ],
                  ),
      ),
    );
  }
}
