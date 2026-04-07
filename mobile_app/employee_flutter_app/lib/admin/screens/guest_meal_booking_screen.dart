import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/daily_resolved_menu.dart';
import '../../models/resolved_meal_option.dart';
import '../../services/meal_reservation_service.dart';
import '../../services/user_profile_service.dart';
import '../services/menu_resolver_service.dart';

class GuestMealBookingScreen extends StatefulWidget {
  final String userEmail;

  const GuestMealBookingScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<GuestMealBookingScreen> createState() => _GuestMealBookingScreenState();
}

class _GuestMealBookingScreenState extends State<GuestMealBookingScreen>
    with SingleTickerProviderStateMixin {
  final MealReservationService _mealReservationService =
      MealReservationService();
  final MenuResolverService _menuResolverService = MenuResolverService();
  final UserProfileService _userProfileService = UserProfileService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  AppUserProfile? _currentUserProfile;
  bool _isLoadingProfile = true;
  bool _isLoadingMenu = false;
  bool _isSaving = false;

  late DateTime _selectedDate;
  DailyResolvedMenu? _resolvedMenu;

  bool _allowGuestBooking = true;
  bool _allowProxyEmployeeBooking = true;
  bool _requireOverrideReason = false;

  String _selectedGuestMealType = 'breakfast';
  String? _selectedGuestDiningMode = 'dine_in';
  String? _selectedGuestOptionKey;
  int _guestQuantity = 1;

  final TextEditingController _guestQuantityController =
      TextEditingController(text: '1');
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _guestHostEmployeeNumberController =
      TextEditingController();
  final TextEditingController _guestHostEmployeeNameController =
      TextEditingController();
  final TextEditingController _guestNotesController = TextEditingController();
  final TextEditingController _guestOverrideReasonController =
      TextEditingController();

  String _selectedProxyMealType = 'breakfast';
  String? _selectedProxyDiningMode = 'dine_in';
  String? _selectedProxyOptionKey;
  int _proxyQuantity = 1;

  final TextEditingController _proxyQuantityController =
      TextEditingController(text: '1');
  final TextEditingController _proxyEmployeeNumberController =
      TextEditingController();
  final TextEditingController _proxyEmployeeNameController =
      TextEditingController();
  final TextEditingController _proxyNotesController = TextEditingController();
  final TextEditingController _proxyOverrideReasonController =
      TextEditingController();

  bool _isLoadingEmployee = false;
  bool _employeeLoaded = false;
  bool _loadedEmployeeIsActive = false;

  String _proxySelectionMode = 'combo';
  List<Map<String, dynamic>> _allMenuItems = [];
  String? _selectedManualItemId;
  bool _isLoadingMenuItems = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate = _resolveOperationalReferenceDate();
    _initializeScreen();
  }

  @override
  void dispose() {
    _tabController.dispose();

    _guestQuantityController.dispose();
    _guestNameController.dispose();
    _guestHostEmployeeNumberController.dispose();
    _guestHostEmployeeNameController.dispose();
    _guestNotesController.dispose();
    _guestOverrideReasonController.dispose();

    _proxyQuantityController.dispose();
    _proxyEmployeeNumberController.dispose();
    _proxyEmployeeNameController.dispose();
    _proxyNotesController.dispose();
    _proxyOverrideReasonController.dispose();

    super.dispose();
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _resolveOperationalReferenceDate() {
    final now = DateTime.now();
    if (now.hour < 6) {
      return _startOfDay(now.subtract(const Duration(days: 1)));
    }
    return _startOfDay(now);
  }

  Future<void> _initializeScreen() async {
    await Future.wait([
      _loadCurrentUserProfile(),
      _loadReservationSettings(),
    ]);

    await Future.wait([
      _loadMenuForDate(_selectedDate),
      _loadAllMenuItems(),
    ]);
  }

  Future<void> _loadCurrentUserProfile() async {
    final authUser = FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      if (!mounted) return;
      setState(() {
        _currentUserProfile = null;
        _isLoadingProfile = false;
      });
      return;
    }

    try {
      final profile = await _userProfileService.resolveCurrentUserProfile(
        authUid: authUser.uid,
      );

      if (!mounted) return;
      setState(() {
        _currentUserProfile = profile;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserProfile = null;
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadReservationSettings() async {
    try {
      final snapshot =
          await _firestore.collection('reservation_settings').limit(1).get();

      if (snapshot.docs.isEmpty) {
        return;
      }

      final data = snapshot.docs.first.data();

      if (!mounted) return;
      setState(() {
        _allowGuestBooking = _readFlexibleBool(
          data['allow_guest_booking'],
          fallback: true,
        );
        _allowProxyEmployeeBooking = _readFlexibleBool(
          data['allow_proxy_employee_booking'],
          fallback: true,
        );
        _requireOverrideReason = _readFlexibleBool(
          data['require_override_reason'],
          fallback: false,
        );
      });
    } catch (_) {}
  }

  Future<void> _loadMenuForDate(DateTime date) async {
    if (!mounted) return;
    setState(() {
      _isLoadingMenu = true;
    });

    try {
      final normalizedDate = _startOfDay(date);
      final menu = await _menuResolverService.getBookingMenuForDate(
        normalizedDate,
      );

      if (!mounted) return;
      setState(() {
        _resolvedMenu = menu;
        _selectedDate = normalizedDate;
        _selectedGuestOptionKey = null;
        _selectedProxyOptionKey = null;
      });

      _ensureValidGuestSelection();
      _ensureValidProxySelection();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolvedMenu = null;
        _selectedDate = _startOfDay(date);
        _selectedGuestOptionKey = null;
        _selectedProxyOptionKey = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMenu = false;
        });
      }
    }
  }

  Future<void> _loadAllMenuItems() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMenuItems = true;
    });

    try {
      final snapshot = await _firestore
          .collection('menu_items')
          .where('is_active', isEqualTo: true)
          .get();

      if (!mounted) return;

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
      final name = (data['name'] ?? data['item_name'] ?? '')
          .toString()
          .trim();

      final baseUnit = (data['base_unit'] ?? '')
          .toString()
          .trim();

      final displayName = baseUnit.isNotEmpty
          ? '$name ($baseUnit)'
          : name;

      return <String, dynamic>{
        'id': doc.id,
        'name': name,
        'display_name': displayName,
        'base_unit': baseUnit,
        'category':
            (data['category'] ?? '').toString().trim().toLowerCase(),
      };
      }).where((item) => (item['name'] as String).isNotEmpty).toList()
        ..sort(
          (a, b) => (a['name'] as String)
              .toLowerCase()
              .compareTo((b['name'] as String).toLowerCase()),
        );

      setState(() {
        _allMenuItems = items;
      });
      _ensureValidProxySelection();
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Failed to load menu items.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMenuItems = false;
        });
      }
    }
  }

  Future<void> _pickReservationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _startOfDay(now).subtract(const Duration(days: 30)),
      lastDate: _startOfDay(now).add(const Duration(days: 30)),
    );

    if (picked == null) {
      return;
    }

    await _loadMenuForDate(_startOfDay(picked));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findEmployeeByDocId(
    String employeeNumber,
  ) async {
    final doc =
        await _firestore.collection('employees').doc(employeeNumber).get();
    if (doc.exists && doc.data() != null) {
      return doc;
    }
    return null;
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findEmployeeByField(
    String fieldName,
    String employeeNumber,
  ) async {
    final query = await _firestore
        .collection('employees')
        .where(fieldName, isEqualTo: employeeNumber)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }
    return query.docs.first;
  }

  String _extractEmployeeName(Map<String, dynamic> data) {
    return (data['name'] ??
            data['employee_name'] ??
            data['full_name'] ??
            '')
        .toString()
        .trim();
  }

  String _extractEmployeeNumber(Map<String, dynamic> data, String fallback) {
    return (data['employee_number'] ??
            data['employee_no'] ??
            data['emp_no'] ??
            data['employeeNumber'] ??
            fallback)
        .toString()
        .trim()
        .toUpperCase();
  }

  bool _extractEmployeeActive(Map<String, dynamic> data) {
    if (data['is_active'] is bool) {
      return data['is_active'] == true;
    }

    final status = (data['status'] ??
            data['record_status'] ??
            data['employment_status'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    if (status == 'active' || status == 'enabled') {
      return true;
    }
    if (status == 'inactive' || status == 'disabled' || status == 'terminated') {
      return false;
    }

    return _readFlexibleBool(
      data['is_active'] ?? data['active'],
      fallback: true,
    );
  }

  Future<void> _loadEmployeeMasterRecord() async {
    final employeeNumber =
        _proxyEmployeeNumberController.text.trim().toUpperCase();

    if (employeeNumber.isEmpty) {
      _showSnackBar('Enter employee number first.');
      return;
    }

    setState(() {
      _isLoadingEmployee = true;
      _employeeLoaded = false;
      _loadedEmployeeIsActive = false;
      _proxyEmployeeNameController.clear();
    });

    try {
      Map<String, dynamic>? employeeData;

      final directDoc = await _findEmployeeByDocId(employeeNumber);
      if (directDoc != null) {
        employeeData = directDoc.data();
      }

      employeeData ??=
          (await _findEmployeeByField('employee_number', employeeNumber))
              ?.data();

      employeeData ??=
          (await _findEmployeeByField('employee_no', employeeNumber))?.data();

      employeeData ??=
          (await _findEmployeeByField('emp_no', employeeNumber))?.data();

      employeeData ??=
          (await _findEmployeeByField('employeeNumber', employeeNumber))
              ?.data();

      if (!mounted) return;

      if (employeeData == null) {
        setState(() {
          _employeeLoaded = false;
        });
        _showSnackBar('Employee master record not found.');
        return;
      }

      final employeeName = _extractEmployeeName(employeeData);
      final isActive = _extractEmployeeActive(employeeData);
      final resolvedEmployeeNumber =
          _extractEmployeeNumber(employeeData, employeeNumber);

      setState(() {
        _proxyEmployeeNumberController.text = resolvedEmployeeNumber;
        _proxyEmployeeNameController.text = employeeName;
        _employeeLoaded = employeeName.isNotEmpty;
        _loadedEmployeeIsActive = isActive;
      });

      if (employeeName.isEmpty) {
        _showSnackBar('Employee record found but employee name is blank.');
        return;
      }

      if (!isActive) {
        _showSnackBar('Employee master record is inactive.');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to load employee: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEmployee = false;
        });
      }
    }
  }

  Future<void> _saveGuestBooking() async {
    if (_isSaving) return;

    if (!_allowGuestBooking) {
      _showSnackBar('Guest booking is disabled in reservation settings.');
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    final profile = _currentUserProfile;

    if (authUser == null || profile == null) {
      _showSnackBar('Authenticated operator profile could not be resolved.');
      return;
    }

    final selectedOption = _selectedGuestOption;
    if (selectedOption == null) {
      _showSnackBar('Select a valid menu option first.');
      return;
    }

    if (_selectedGuestDiningMode == null || _selectedGuestDiningMode!.isEmpty) {
      _showSnackBar('Select dining mode.');
      return;
    }

    final guestName = _guestNameController.text.trim();
    if (guestName.isEmpty) {
      _showSnackBar('Guest name / label is required.');
      return;
    }

    final hostEmployeeNumber =
        _guestHostEmployeeNumberController.text.trim().toUpperCase();
    if (hostEmployeeNumber.isEmpty) {
      _showSnackBar('Host employee number is required.');
      return;
    }

    _guestQuantity = int.tryParse(_guestQuantityController.text.trim()) ?? 1;
    if (_guestQuantity <= 0) {
      _showSnackBar('Quantity must be greater than zero.');
      return;
    }

    final overrideReason = _guestOverrideReasonController.text.trim();

    if (_requireOverrideReason && overrideReason.isEmpty) {
      _showSnackBar('Override reason is required.');
      return;
    }

    final lines = [
      ReservationLineInput.forCycleOption(
        optionKey: selectedOption.optionKey,
        optionLabel: selectedOption.optionLabel,
        diningMode: _selectedGuestDiningMode!,
        quantity: _guestQuantity,
        menuSnapshot: {
          'selection_type': MealReservationService.selectionModeCycleCombo,
          'option_key': selectedOption.optionKey,
          'option_label': selectedOption.optionLabel,
          'meal_type': _selectedGuestMealType,
          'items': selectedOption.items,
        },
      ),
    ];

    setState(() {
      _isSaving = true;
    });

    try {
      await _mealReservationService.createGuestReservationGroup(
        reservationDate: _selectedDate,
        mealType: _selectedGuestMealType,
        lines: lines,
        createdByUid: authUser.uid,
        createdByRole: _normalizedRole(profile.roleLabel),
        createdByEmployeeNumber: profile.employeeNumber,
        createdByName: profile.employeeName,
        guestName: guestName,
        hostEmployeeNumber: hostEmployeeNumber,
        hostEmployeeName: _guestHostEmployeeNameController.text.trim(),
        notes: _guestNotesController.text.trim(),
        overrideReason: overrideReason.isEmpty ? null : overrideReason,
        skipValidation: true,
      );

      if (!mounted) return;

      _guestNameController.clear();
      _guestHostEmployeeNumberController.clear();
      _guestHostEmployeeNameController.clear();
      _guestNotesController.clear();
      _guestOverrideReasonController.clear();

      setState(() {
        _guestQuantity = 1;
        _guestQuantityController.text = '1';
      });

      _showSnackBar(
        'Guest booking saved for ${_mealLabel(_selectedGuestMealType)} on ${_formatDate(_selectedDate)}.',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to save guest booking: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveProxyEmployeeBooking() async {
    if (_isSaving) return;

    if (!_allowProxyEmployeeBooking) {
      _showSnackBar(
        'Proxy employee booking is disabled in reservation settings.',
      );
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    final profile = _currentUserProfile;

    if (authUser == null || profile == null) {
      _showSnackBar('Authenticated operator profile could not be resolved.');
      return;
    }

    final employeeNumber =
        _proxyEmployeeNumberController.text.trim().toUpperCase();
    final employeeName = _proxyEmployeeNameController.text.trim();

    if (employeeNumber.isEmpty) {
      _showSnackBar('Employee number is required.');
      return;
    }

    if (employeeName.isEmpty) {
      _showSnackBar('Load a valid employee first.');
      return;
    }

    if (!_employeeLoaded) {
      _showSnackBar('Load employee master record before saving.');
      return;
    }

    if (!_loadedEmployeeIsActive) {
      _showSnackBar('Inactive employee cannot be booked.');
      return;
    }

    if (_selectedProxyDiningMode == null || _selectedProxyDiningMode!.isEmpty) {
      _showSnackBar('Select dining mode.');
      return;
    }

    _proxyQuantity = int.tryParse(_proxyQuantityController.text.trim()) ?? 1;
    if (_proxyQuantity <= 0) {
      _showSnackBar('Quantity must be greater than zero.');
      return;
    }

    final overrideReason = _proxyOverrideReasonController.text.trim();

    if (_requireOverrideReason && overrideReason.isEmpty) {
      _showSnackBar('Override reason is required.');
      return;
    }

    List<ReservationLineInput> lines;
    String selectionMode;
    bool allowAnyMenuItem = false;
    bool isSpecialMeal = false;
    String requestContext = 'proxy_request';

    if (_proxySelectionMode == 'combo') {
      final selectedOption = _selectedProxyOption;

      if (selectedOption == null) {
        _showSnackBar('Select a valid menu option first.');
        return;
      }

      lines = [
        ReservationLineInput.forCycleOption(
          optionKey: selectedOption.optionKey,
          optionLabel: selectedOption.optionLabel,
          diningMode: _selectedProxyDiningMode!,
          quantity: _proxyQuantity,
          menuSnapshot: {
            'selection_type': MealReservationService.selectionModeCycleCombo,
            'option_key': selectedOption.optionKey,
            'option_label': selectedOption.optionLabel,
            'meal_type': _selectedProxyMealType,
            'items': selectedOption.items,
          },
        ),
      ];
      selectionMode = MealReservationService.selectionModeCycleCombo;
    } else {
      final manualItem = _selectedManualItem;
      if (manualItem == null) {
        _showSnackBar('Select a special item from full menu.');
        return;
      }

      lines = [
        ReservationLineInput.forManualItem(
          itemId: (manualItem['id'] ?? '').toString(),
          itemName: (manualItem['name'] ?? '').toString(),
          diningMode: _selectedProxyDiningMode!,
          quantity: _proxyQuantity,
          mealType: _selectedProxyMealType,
          itemCategory: (manualItem['category'] ?? '').toString(),
          extraSnapshot: {
            'source_scope': 'full_menu_master',
            'selected_for_meal_type': _selectedProxyMealType,
          },
        ),
      ];
      selectionMode = MealReservationService.selectionModeManualItem;
      allowAnyMenuItem = true;
      isSpecialMeal = true;
      requestContext = 'special_request';
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _mealReservationService.createProxyEmployeeReservationGroup(
        employeeNumber: employeeNumber,
        employeeName: employeeName,
        reservationDate: _selectedDate,
        mealType: _selectedProxyMealType,
        lines: lines,
        createdByUid: authUser.uid,
        createdByRole: _normalizedRole(profile.roleLabel),
        createdByEmployeeNumber: profile.employeeNumber,
        createdByName: profile.employeeName,
        notes: _proxyNotesController.text.trim(),
        overrideReason: overrideReason.isEmpty ? null : overrideReason,
        selectionMode: selectionMode,
        requestContext: requestContext,
        isSpecialMeal: isSpecialMeal,
        allowAnyMenuItem: allowAnyMenuItem,
        skipValidation: true,
      );

      if (!mounted) return;

      _proxyEmployeeNumberController.clear();
      _proxyEmployeeNameController.clear();
      _proxyNotesController.clear();
      _proxyOverrideReasonController.clear();

      setState(() {
        _proxyQuantity = 1;
        _proxyQuantityController.text = '1';
        _employeeLoaded = false;
        _loadedEmployeeIsActive = false;
        _selectedManualItemId = null;
        _selectedProxyOptionKey = null;
      });

      _ensureValidProxySelection();

      _showSnackBar(
        'Proxy employee booking saved for ${_mealLabel(_selectedProxyMealType)} on ${_formatDate(_selectedDate)}.',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to save employee booking: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<ResolvedMealOption> _optionsForMealType(String mealType) {
    final menu = _resolvedMenu;
    if (menu == null) {
      return const <ResolvedMealOption>[];
    }

    switch (mealType) {
      case 'breakfast':
        return menu.breakfastOptions;
      case 'lunch':
        return menu.lunchOptions;
      case 'dinner':
        return menu.dinnerOptions;
      default:
        return const <ResolvedMealOption>[];
    }
  }

  List<Map<String, dynamic>> _menuItemsForMealType(String mealType) {
    final normalizedMealType = mealType.trim().toLowerCase();

    final filtered = _allMenuItems.where((item) {
      final category = (item['category'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (category.isEmpty) {
        return true;
      }
      return category == normalizedMealType;
    }).toList();

    if (filtered.isNotEmpty) {
      return filtered;
    }

    return _allMenuItems;
  }

  ResolvedMealOption? get _selectedGuestOption {
    final options = _optionsForMealType(_selectedGuestMealType);
    if (options.isEmpty) {
      return null;
    }

    try {
      return options.firstWhere(
        (item) => item.optionKey == _selectedGuestOptionKey,
      );
    } catch (_) {
      return null;
    }
  }

  ResolvedMealOption? get _selectedProxyOption {
    final options = _optionsForMealType(_selectedProxyMealType);
    if (options.isEmpty) {
      return null;
    }

    try {
      return options.firstWhere(
        (item) => item.optionKey == _selectedProxyOptionKey,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get _selectedManualItem {
    final items = _menuItemsForMealType(_selectedProxyMealType);
    if (items.isEmpty || _selectedManualItemId == null) {
      return null;
    }

    try {
      return items.firstWhere((item) => item['id'] == _selectedManualItemId);
    } catch (_) {
      return null;
    }
  }

  void _ensureValidGuestSelection() {
    final options = _optionsForMealType(_selectedGuestMealType);

    if (!mounted) return;
    setState(() {
      if (options.isEmpty) {
        _selectedGuestOptionKey = null;
      } else if (_selectedGuestOptionKey == null ||
          !options.any((item) => item.optionKey == _selectedGuestOptionKey)) {
        _selectedGuestOptionKey = options.first.optionKey;
      }
    });
  }

  void _ensureValidProxySelection() {
    final options = _optionsForMealType(_selectedProxyMealType);
    final manualItems = _menuItemsForMealType(_selectedProxyMealType);

    if (!mounted) return;
    setState(() {
      if (options.isEmpty) {
        _selectedProxyOptionKey = null;
      } else if (_selectedProxyOptionKey == null ||
          !options.any((item) => item.optionKey == _selectedProxyOptionKey)) {
        _selectedProxyOptionKey = options.first.optionKey;
      }

      if (manualItems.isEmpty) {
        _selectedManualItemId = null;
      } else if (_selectedManualItemId == null ||
          !manualItems.any((item) => item['id'] == _selectedManualItemId)) {
        _selectedManualItemId = manualItems.first['id'] as String;
      }
    });
  }

  bool _readFlexibleBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }

    final normalized = (value ?? '').toString().trim().toLowerCase();

    if (normalized == 'yes' ||
        normalized == 'true' ||
        normalized == '1' ||
        normalized == 'enabled') {
      return true;
    }

    if (normalized == 'no' ||
        normalized == 'false' ||
        normalized == '0' ||
        normalized == 'disabled') {
      return false;
    }

    return fallback;
  }

  String _normalizedRole(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '_');
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
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

  String _buildItemsSummary(ResolvedMealOption option) {
    if (option.items.isEmpty) {
      return 'No items listed';
    }

    final names = option.items
        .map(
          (item) => (item['item_name'] ?? item['name'] ?? item['item_id'] ?? '')
              .toString()
              .trim(),
        )
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isEmpty) {
      return 'No items listed';
    }

    return names.join(', ');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildTopSummaryCard() {
    final profile = _currentUserProfile;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          runSpacing: 12,
          spacing: 24,
          children: [
            _SummaryTile(
              label: 'Operator',
              value: profile?.employeeName.isNotEmpty == true
                  ? profile!.employeeName
                  : widget.userEmail,
            ),
            _SummaryTile(
              label: 'Role',
              value: profile?.roleLabel ?? 'unknown',
            ),
            _SummaryTile(
              label: 'Date',
              value: _formatDate(_selectedDate),
            ),
            _SummaryTile(
              label: 'Cycle',
              value: _resolvedMenu?.cycleName.isNotEmpty == true
                  ? _resolvedMenu!.cycleName
                  : 'No active cycle',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuStatusCard() {
    if (_isLoadingMenu) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Loading menu...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              LinearProgressIndicator(),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          runSpacing: 10,
          spacing: 12,
          children: [
            ActionChip(
              avatar: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('Date: ${_formatDate(_selectedDate)}'),
              onPressed: _pickReservationDate,
            ),
            ActionChip(
              avatar: const Icon(Icons.refresh, size: 18),
              label: const Text('Reload Menu'),
              onPressed: () async {
                await Future.wait([
                  _loadMenuForDate(_selectedDate),
                  _loadAllMenuItems(),
                ]);
              },
            ),
            if (!_allowGuestBooking)
              const Chip(
                label: Text('Guest booking disabled'),
              ),
            if (!_allowProxyEmployeeBooking)
              const Chip(
                label: Text('Proxy booking disabled'),
              ),
            if (_resolvedMenu == null)
              const Chip(
                label: Text('No active cycle menu'),
              ),
            if (_isLoadingMenuItems)
              const Chip(
                label: Text('Loading full menu items...'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestTab() {
    final options = _optionsForMealType(_selectedGuestMealType);
    final selectedOption = _selectedGuestOption;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Guest Booking',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use this form to reserve meals for official guests or future non-employee consumers.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGuestMealType,
                        decoration: const InputDecoration(
                          labelText: 'Meal Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'breakfast',
                            child: Text('Breakfast'),
                          ),
                          DropdownMenuItem(
                            value: 'lunch',
                            child: Text('Lunch'),
                          ),
                          DropdownMenuItem(
                            value: 'dinner',
                            child: Text('Dinner'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedGuestMealType = value;
                          });
                          _ensureValidGuestSelection();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedGuestDiningMode,
                        decoration: const InputDecoration(
                          labelText: 'Dining Mode',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'dine_in',
                            child: Text('Dine In'),
                          ),
                          DropdownMenuItem(
                            value: 'takeaway',
                            child: Text('Takeaway'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedGuestDiningMode = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGuestOptionKey,
                  decoration: const InputDecoration(
                    labelText: 'Menu Option',
                    border: OutlineInputBorder(),
                  ),
                  items: options
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.optionKey,
                          child: Text(option.optionLabel),
                        ),
                      )
                      .toList(),
                  onChanged: options.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            _selectedGuestOptionKey = value;
                          });
                        },
                ),
                if (options.isEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'No guest bookable combo found for selected meal/date.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
                if (selectedOption != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _buildItemsSummary(selectedOption),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _guestQuantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _guestQuantity = int.tryParse(value.trim()) ?? 1;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _guestNameController,
                  decoration: const InputDecoration(
                    labelText: 'Guest Name / Label',
                    hintText:
                        'e.g. Head Office Guest / Vendor Team / Mr. Ali',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _guestHostEmployeeNumberController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Host Employee Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _guestHostEmployeeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Host Employee Name (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _guestNotesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _guestOverrideReasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Override Reason (if required)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: (_isSaving || options.isEmpty)
                      ? null
                      : _saveGuestBooking,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Save Guest Booking'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProxyTab() {
    final options = _optionsForMealType(_selectedProxyMealType);
    final selectedOption = _selectedProxyOption;
    final manualItems = _menuItemsForMealType(_selectedProxyMealType);
    final selectedManualItem = _selectedManualItem;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Book for Employee',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use this form when an employee cannot access mobile or internet and booking must be entered by manager or supervisor.',
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _proxyEmployeeNumberController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Employee Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed:
                            _isLoadingEmployee ? null : _loadEmployeeMasterRecord,
                        icon: _isLoadingEmployee
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: const Text('Load'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _proxyEmployeeNameController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Employee Name',
                    border: const OutlineInputBorder(),
                    suffixIcon: _employeeLoaded
                        ? Icon(
                            _loadedEmployeeIsActive
                                ? Icons.verified_outlined
                                : Icons.warning_amber_outlined,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedProxyMealType,
                        decoration: const InputDecoration(
                          labelText: 'Meal Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'breakfast',
                            child: Text('Breakfast'),
                          ),
                          DropdownMenuItem(
                            value: 'lunch',
                            child: Text('Lunch'),
                          ),
                          DropdownMenuItem(
                            value: 'dinner',
                            child: Text('Dinner'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedProxyMealType = value;
                          });
                          _ensureValidProxySelection();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedProxyDiningMode,
                        decoration: const InputDecoration(
                          labelText: 'Dining Mode',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'dine_in',
                            child: Text('Dine In'),
                          ),
                          DropdownMenuItem(
                            value: 'takeaway',
                            child: Text('Takeaway'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedProxyDiningMode = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _proxySelectionMode,
                  decoration: const InputDecoration(
                    labelText: 'Booking Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'combo',
                      child: Text('Combo'),
                    ),
                    DropdownMenuItem(
                      value: 'manual_item',
                      child: Text('Special Item'),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() {
                      _proxySelectionMode = value;
                    });

                    if (value == 'manual_item' && _allMenuItems.isEmpty) {
                      await _loadAllMenuItems();
                    }
                    _ensureValidProxySelection();
                  },
                ),
                const SizedBox(height: 12),
                if (_proxySelectionMode == 'combo') ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProxyOptionKey,
                    decoration: const InputDecoration(
                      labelText: 'Menu Option',
                      border: OutlineInputBorder(),
                    ),
                    items: options
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option.optionKey,
                            child: Text(option.optionLabel),
                          ),
                        )
                        .toList(),
                    onChanged: options.isEmpty
                        ? null
                        : (value) {
                            setState(() {
                              _selectedProxyOptionKey = value;
                            });
                          },
                  ),
                  if (options.isEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'No combo option found in current cycle for selected meal/date.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                  if (selectedOption != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _buildItemsSummary(selectedOption),
                      ),
                    ),
                  ],
                ] else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedManualItemId,
                    decoration: const InputDecoration(
                      labelText: 'Select Item (Full Menu)',
                      border: OutlineInputBorder(),
                    ),
                    items: manualItems
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item['id'] as String,
                            child: Text(item['display_name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: manualItems.isEmpty
                        ? null
                        : (value) {
                            setState(() {
                              _selectedManualItemId = value;
                            });
                          },
                  ),
                  if (_isLoadingMenuItems) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(),
                  ],
                  if (manualItems.isEmpty && !_isLoadingMenuItems) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'No active menu items available for special booking.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                  if (selectedManualItem != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Selected special item: ${selectedManualItem['display_name'] ?? selectedManualItem['name']}'
                        '${((selectedManualItem['category'] ?? '').toString().isNotEmpty) ? ' (${selectedManualItem['category']})' : ''}',
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _proxyQuantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _proxyQuantity = int.tryParse(value.trim()) ?? 1;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _proxyNotesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _proxyOverrideReasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Override Reason (if required)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProxyEmployeeBooking,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Save Employee Booking'),
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
    if (_isLoadingProfile) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_currentUserProfile == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Operator profile could not be resolved.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTopSummaryCard(),
              const SizedBox(height: 12),
              _buildMenuStatusCard(),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.groups_outlined),
                          text: 'Guest Booking',
                        ),
                        Tab(
                          icon: Icon(Icons.badge_outlined),
                          text: 'Book for Employee',
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 920,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildGuestTab(),
                          _buildProxyTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
