class ReservationConstants {
  ReservationConstants._();

  // Collection names
  static const String mealReservationsCollection = 'meal_reservations';
  static const String reservationSettingsCollection = 'reservation_settings';

  // Meal types
  static const String breakfast = 'breakfast';
  static const String lunch = 'lunch';
  static const String dinner = 'dinner';

  static const List<String> mealTypes = [
    breakfast,
    lunch,
    dinner,
  ];

  // Reservation categories
  static const String employee = 'employee';
  static const String officialGuest = 'official_guest';

  static const List<String> reservationCategories = [
    employee,
    officialGuest,
  ];

  // Service modes
  static const String dineIn = 'dine_in';
  static const String takeaway = 'takeaway';

  static const List<String> serviceModes = [
    dineIn,
    takeaway,
  ];

  // Booking sources
  static const String employeeApp = 'employee_app';
  static const String supervisorConsole = 'supervisor_console';
  static const String adminConsole = 'admin_console';

  static const List<String> bookingSources = [
    employeeApp,
    supervisorConsole,
    adminConsole,
  ];

  // Reservation status
  static const String active = 'active';
  static const String cancelled = 'cancelled';
  static const String consumed = 'consumed';

  static const List<String> reservationStatuses = [
    active,
    cancelled,
    consumed,
  ];

  // Option keys (for structured menu selection)
  static const String breakfastOption1 = 'breakfast_option_1';
  static const String breakfastOption2 = 'breakfast_option_2';
  static const String lunchCombo1 = 'lunch_combo_1';
  static const String lunchCombo2 = 'lunch_combo_2';
  static const String dinnerCombo1 = 'dinner_combo_1';
  static const String dinnerCombo2 = 'dinner_combo_2';

  static const List<String> knownOptionKeys = [
    breakfastOption1,
    breakfastOption2,
    lunchCombo1,
    lunchCombo2,
    dinnerCombo1,
    dinnerCombo2,
  ];
}
