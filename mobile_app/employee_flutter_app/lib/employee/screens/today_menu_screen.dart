import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../admin/services/menu_resolver_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedDate = _resolveOperationalReferenceDate();
    _loadScreenData();
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _resolveOperationalReferenceDate() {
    final now = DateTime.now();
    if (now.hour < 6) {
      return _normalizeDate(now.subtract(const Duration(days: 1)));
    }
    return _normalizeDate(now);
  }

  Future<void> _loadScreenData({bool forceRefresh = false}) async {
    final normalizedDate = _normalizeDate(_selectedDate);

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _identityWarning = null;
    });

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        throw Exception('No authenticated user found.');
      }

      final results = await Future.wait<dynamic>([
        _menuResolverService.getBookingMenuForDate(
          normalizedDate,
          forceRefresh: forceRefresh,
        ),
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

  String _formatCurrency(dynamic value) {
    if (value is int) return value.toDouble().toStringAsFixed(2);
    if (value is double) return value.toStringAsFixed(2);
    final parsed = double.tryParse((value ?? '').toString());
    return (parsed ?? 0).toStringAsFixed(2);
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
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day).subtract(
        const Duration(days: 1),
      ),
      lastDate: DateTime(now.year, now.month, now.day).add(
        const Duration(days: 30),
      ),
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

      final baseSnapshot = <String, dynamic>{
        'selection_type': MealReservationService.selectionModeCycleCombo,
        'option_key': option.optionKey,
        'option_label': option.optionLabel,
        'meal_type': mealType,
        'items': option.items,
      };

      if (draft.dineInQuantity > 0) {
        selectedLines.add(
          ReservationLineInput.forCycleOption(
            optionKey: option.optionKey,
            optionLabel: option.optionLabel,
            diningMode: 'dine_in',
            quantity: draft.dineInQuantity,
            menuSnapshot: baseSnapshot,
          ),
        );
      }

      if (draft.takeawayQuantity > 0) {
        selectedLines.add(
          ReservationLineInput.forCycleOption(
            optionKey: option.optionKey,
            optionLabel: option.optionLabel,
            diningMode: 'takeaway',
            quantity: draft.takeawayQuantity,
            menuSnapshot: baseSnapshot,
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

    final bookingGroupIds = docs
        .map((doc) => (doc.data()['booking_group_id'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    setState(() {
      _isSaving = true;
    });

    try {
      if (bookingGroupIds.length == 1) {
        await _mealReservationService.cancelReservationGroup(
          bookingGroupId: bookingGroupIds.first,
          cancelledByUid: authUser.uid,
          cancelledByRole: 'employee',
        );
      } else {
        for (final doc in docs) {
          await _mealReservationService.cancelReservation(
            reservationId: doc.id,
            cancelledByUid: authUser.uid,
            cancelledByRole: 'employee',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _draftsByMeal[mealType]!.clear();
      });

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

  Widget _buildHeroCard() {
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
          runSpacing: AppSpacing.md,
          spacing: AppSpacing.lg,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.visibleAppName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Meal Reservation',
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
                    'Reservation Date: ${_formatDate(_selectedDate)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  if (_dailyMenu != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Cycle: ${_dailyMenu!.cycleName} • ${_dailyMenu!.weekday}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
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
                  onPressed: _isSaving ? null : _pickDate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Select Date'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      _isSaving ? null : () => _loadScreenData(forceRefresh: true),
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

  Widget _buildIdentityCard() {
    final theme = Theme.of(context);
    final identity = _identityResult;
    final employeeNumber = identity?.employeeNumber?.trim() ?? '';
    final employeeName = (_userProfile?.employeeName ?? '').trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Identity & Booking Status',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            _SummaryRow(
              label: 'Employee Name',
              value: employeeName.isEmpty ? '—' : employeeName,
            ),
            const SizedBox(height: AppSpacing.sm),
            _SummaryRow(
              label: 'Employee Number',
              value: employeeNumber.isEmpty ? '—' : employeeNumber,
            ),
            const SizedBox(height: AppSpacing.sm),
            _SummaryRow(
              label: 'Profile Role',
              value: _userProfile?.roleLabel ?? '—',
            ),
            if (_identityWarning != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  _identityWarning!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(String mealType, ResolvedMealOption option) {
    final draft = _draftFor(mealType, option.optionKey);
    final isPreferredMode = widget.initialDiningMode == 'takeaway';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              option.optionLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _buildItemsSummary(option),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _QuantityEditor(
                    label: 'Dine In',
                    value: draft.dineInQuantity,
                    highlighted: !isPreferredMode,
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
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _QuantityEditor(
                    label: 'Takeaway',
                    value: draft.takeawayQuantity,
                    highlighted: isPreferredMode,
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
        final option =
            (data['option_label'] ?? data['item_name'] ?? '').toString();
        final mode = (data['dining_mode'] ?? '').toString();
        final qty = (data['quantity'] ?? 0).toString();
        final status = (data['status'] ?? '').toString();
        final issued = data['is_issued'] == true;
        final unitRate = data['unit_rate'];
        final amount = data['amount'];
        final createdAt = _formatDateTime(data['created_at']);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: issued
                ? AppColors.success.withValues(alpha: 0.08)
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: issued
                  ? AppColors.success.withValues(alpha: 0.2)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.isEmpty ? 'Reserved option' : option,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Dining Mode: ${_modeLabel(mode)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Quantity: $qty',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Unit Rate: ${_formatCurrency(unitRate)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Amount: ${_formatCurrency(amount)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Status: ${issued ? 'Issued' : status}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Created At: $createdAt',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
    final theme = Theme.of(context);
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

    final icon = mealType == 'breakfast'
        ? Icons.free_breakfast_outlined
        : mealType == 'lunch'
            ? Icons.lunch_dining_outlined
            : Icons.dinner_dining_outlined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              runSpacing: AppSpacing.sm,
              spacing: AppSpacing.sm,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                    Text(
                      _mealLabel(mealType),
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
                if (hasExistingReservation)
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
                      'Reserved',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (!hasExistingReservation && !bookingValidation.isAllowed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  bookingValidation.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (hasExistingReservation &&
                !cancellationValidation.isAllowed &&
                cancellationValidation.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  cancellationValidation.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (hasExistingReservation)
              _buildExistingReservationsSection(mealType)
            else if (options.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Text(
                  'No menu available for this meal.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              ...options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _buildOptionTile(mealType, option),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
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

  Widget _buildLoadingView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Reservation'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildHeroCard(),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Loading reservation screen...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Reservation'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Menu Load Error',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Reservation'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _loadScreenData(forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _buildHeroCard(),
            const SizedBox(height: AppSpacing.md),
            _buildIdentityCard(),
            const SizedBox(height: AppSpacing.md),
            _buildMealCard('breakfast'),
            const SizedBox(height: AppSpacing.md),
            _buildMealCard('lunch'),
            const SizedBox(height: AppSpacing.md),
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
  final bool highlighted;
  final ValueChanged<int> onChanged;

  const _QuantityEditor({
    required this.label,
    required this.value,
    required this.onChanged,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: highlighted ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: highlighted ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
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
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
