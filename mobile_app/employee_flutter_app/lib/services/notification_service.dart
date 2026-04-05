import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('notifications');

  CollectionReference<Map<String, dynamic>> get _deliveriesRef =>
      _firestore.collection('notification_deliveries');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _profilesRef =>
      _firestore.collection('employee_profiles');

  Stream<int> unreadCountStream({
    required String userUid,
  }) {
    return _deliveriesRef
        .where('user_uid', isEqualTo: userUid.trim())
        .where('in_app_enabled', isEqualTo: true)
        .where('in_app_status', whereIn: ['pending', 'visible'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> userDeliveriesStream({
    required String userUid,
  }) {
    return _deliveriesRef
        .where('user_uid', isEqualTo: userUid.trim())
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> eventInvitationPopupStream({
    required String userUid,
  }) {
    return _deliveriesRef
        .where('user_uid', isEqualTo: userUid.trim())
        .where('in_app_enabled', isEqualTo: true)
        .where('type', isEqualTo: 'event_invitation')
        .where('in_app_status', whereIn: ['pending', 'visible'])
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> adminNotificationsStream() {
    return _notificationsRef
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<void> markDeliveryAsRead({
    required String deliveryId,
  }) async {
    final docRef = _deliveriesRef.doc(deliveryId);
    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final data = snapshot.data()!;
    final currentStatus =
        (data['in_app_status'] ?? '').toString().trim().toLowerCase();

    if (currentStatus == 'read' || currentStatus == 'archived') {
      return;
    }

    final now = Timestamp.now();

    await docRef.update({
      'in_app_status': 'read',
      'is_read': true,
      'read_at': now,
      'updated_at': now,
    });
  }

  Future<void> markAllVisibleAsRead({
    required String userUid,
  }) async {
    final snapshot = await _deliveriesRef
        .where('user_uid', isEqualTo: userUid.trim())
        .where('in_app_enabled', isEqualTo: true)
        .where('in_app_status', whereIn: ['pending', 'visible'])
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    final now = Timestamp.now();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'in_app_status': 'read',
        'is_read': true,
        'read_at': now,
        'updated_at': now,
      });
    }

    await batch.commit();
  }

  Future<void> acknowledgePopup({
    required String deliveryId,
  }) async {
    final docRef = _deliveriesRef.doc(deliveryId);
    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final data = snapshot.data()!;
    final currentStatus =
        (data['in_app_status'] ?? '').toString().trim().toLowerCase();
    final now = Timestamp.now();

    if (currentStatus == 'archived') {
      return;
    }

    await docRef.update({
      'popup_acknowledged_at': now,
      'updated_at': now,
      if (currentStatus == 'pending') 'in_app_status': 'visible',
      if (currentStatus == 'pending') 'in_app_visible_at': now,
    });
  }

  Future<String> createAdministrativeNotification({
    required String type,
    required String title,
    required String body,
    required String createdByUid,
    String? createdByName,
    String targetType = 'all_employees',
    List<String>? targetUserUids,
    bool sendInApp = true,
    bool sendPush = true,
    bool sendEmail = true,
    bool requiresReview = true,
    String reviewStatus = 'approved',
    String? reviewedByUid,
    String? contextType,
    String? contextId,
    String priority = 'normal',
    String status = 'published',
    String triggerSource = 'admin_manual',
    Timestamp? publishAt,
    Timestamp? expiresAt,
  }) async {
    final normalizedTargetType = _normalizeTargetType(targetType);
    final normalizedTargets = (targetUserUids ?? <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final recipients = await _resolveAdministrativeTargets(
      targetType: normalizedTargetType,
      targetUserUids: normalizedTargets,
    );

    final docRef = _notificationsRef.doc();
    final now = Timestamp.now();
    final normalizedStatus =
        status.trim().isEmpty ? 'published' : status.trim().toLowerCase();
    final normalizedReviewStatus =
        reviewStatus.trim().isEmpty ? 'approved' : reviewStatus.trim();

    final batch = _firestore.batch();

    batch.set(docRef, <String, dynamic>{
      'notification_id': docRef.id,
      'notification_layer': 'administrative',
      'type': type.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'short_message': title.trim(),
      'status': normalizedStatus,
      'priority': priority.trim().isEmpty ? 'normal' : priority.trim(),
      'target_type': normalizedTargetType,
      'target_user_uid': null,
      'target_user_uids': recipients.map((e) => e.userUid).toList(),
      'send_in_app': sendInApp,
      'send_push': sendPush,
      'send_email': sendEmail,
      'created_by_uid': createdByUid.trim(),
      'created_by_name': createdByName?.trim() ?? '',
      'trigger_source': triggerSource.trim().isEmpty
          ? 'admin_manual'
          : triggerSource.trim(),
      'requires_review': requiresReview,
      'review_status': normalizedReviewStatus,
      'reviewed_by_uid': reviewedByUid?.trim() ?? '',
      'reviewed_at':
          requiresReview && normalizedReviewStatus.toLowerCase() == 'approved'
              ? now
              : null,
      'context_type': contextType?.trim() ?? '',
      'context_id': contextId?.trim() ?? '',
      'reference_type': contextType?.trim() ?? '',
      'reference_id': contextId?.trim() ?? '',
      'email_subject': title.trim(),
      'email_body': body.trim(),
      'push_title': title.trim(),
      'push_body': body.trim(),
      'publish_at': publishAt,
      'published_at': normalizedStatus == 'draft' ? null : now,
      'expires_at': expiresAt,
      'delivery_count_total': recipients.length,
      'delivery_count_in_app': sendInApp ? recipients.length : 0,
      'delivery_count_push_sent': 0,
      'delivery_count_push_failed': 0,
      'delivery_count_email_sent': 0,
      'delivery_count_email_failed': 0,
      'created_at': now,
      'updated_at': now,
    });

    final shouldCreateDeliveries =
        normalizedStatus != 'draft' && recipients.isNotEmpty;

    if (shouldCreateDeliveries) {
      for (final recipient in recipients) {
        final deliveryRef = _deliveriesRef.doc();

        batch.set(deliveryRef, <String, dynamic>{
          'delivery_id': deliveryRef.id,
          'notification_id': docRef.id,
          'user_uid': recipient.userUid,
          'employee_number': recipient.employeeNumber,
          'employee_name': recipient.employeeName,
          'email': recipient.email,
          'notification_layer': 'administrative',
          'type': type.trim(),
          'in_app_enabled': sendInApp,
          'push_enabled': sendPush,
          'email_enabled': sendEmail,
          'in_app_status': sendInApp ? 'visible' : 'skipped',
          'push_status': sendPush ? 'pending' : 'skipped',
          'email_status': sendEmail ? 'pending' : 'skipped',
          'is_read': false,
          'push_sent_at': null,
          'email_sent_at': null,
          'in_app_visible_at': sendInApp ? now : null,
          'read_at': null,
          'archived_at': null,
          'popup_acknowledged_at': null,
          'failure_reason_push': '',
          'failure_reason_email': '',
          'title_snapshot': title.trim(),
          'body_snapshot': body.trim(),
          'context_type': contextType?.trim() ?? '',
          'context_id': contextId?.trim() ?? '',
          'reference_type': contextType?.trim() ?? '',
          'reference_id': contextId?.trim() ?? '',
          'created_at': now,
          'updated_at': now,
        });
      }
    }

    await batch.commit();
    return docRef.id;
  }

  Future<String> createTransactionalNotification({
    required String type,
    required String title,
    required String body,
    required String userUid,
    String? employeeNumber,
    String? employeeName,
    String? email,
    required String contextType,
    required String contextId,
    String triggerSource = 'reservation_service',
    bool sendInApp = true,
    bool sendPush = true,
    bool sendEmail = true,
    String priority = 'normal',
  }) async {
    final normalizedUserUid = userUid.trim();
    if (normalizedUserUid.isEmpty) {
      throw Exception('User UID is required for transactional notification.');
    }

    final notificationRef = _notificationsRef.doc();
    final deliveryRef = _deliveriesRef.doc();
    final now = Timestamp.now();

    final batch = _firestore.batch();

    batch.set(notificationRef, {
      'notification_id': notificationRef.id,
      'notification_layer': 'transactional',
      'type': type.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'short_message': title.trim(),
      'status': 'completed',
      'priority': priority.trim().isEmpty ? 'normal' : priority.trim(),
      'target_type': 'single_user',
      'target_user_uid': normalizedUserUid,
      'target_user_uids': <String>[normalizedUserUid],
      'send_in_app': sendInApp,
      'send_push': sendPush,
      'send_email': sendEmail,
      'created_by_uid': '',
      'created_by_name': '',
      'trigger_source': triggerSource.trim().isEmpty
          ? 'reservation_service'
          : triggerSource.trim(),
      'requires_review': false,
      'review_status': 'not_required',
      'reviewed_by_uid': '',
      'reviewed_at': null,
      'context_type': contextType.trim(),
      'context_id': contextId.trim(),
      'reference_type': contextType.trim(),
      'reference_id': contextId.trim(),
      'email_subject': title.trim(),
      'email_body': body.trim(),
      'push_title': title.trim(),
      'push_body': body.trim(),
      'publish_at': now,
      'published_at': now,
      'expires_at': null,
      'delivery_count_total': 1,
      'delivery_count_in_app': sendInApp ? 1 : 0,
      'delivery_count_push_sent': 0,
      'delivery_count_push_failed': 0,
      'delivery_count_email_sent': 0,
      'delivery_count_email_failed': 0,
      'created_at': now,
      'updated_at': now,
    });

    batch.set(deliveryRef, {
      'delivery_id': deliveryRef.id,
      'notification_id': notificationRef.id,
      'user_uid': normalizedUserUid,
      'employee_number': employeeNumber?.trim() ?? '',
      'employee_name': employeeName?.trim() ?? '',
      'email': email?.trim() ?? '',
      'notification_layer': 'transactional',
      'type': type.trim(),
      'in_app_enabled': sendInApp,
      'push_enabled': sendPush,
      'email_enabled': sendEmail,
      'in_app_status': sendInApp ? 'visible' : 'skipped',
      'push_status': sendPush ? 'pending' : 'skipped',
      'email_status': sendEmail ? 'pending' : 'skipped',
      'is_read': false,
      'push_sent_at': null,
      'email_sent_at': null,
      'in_app_visible_at': sendInApp ? now : null,
      'read_at': null,
      'archived_at': null,
      'popup_acknowledged_at': null,
      'failure_reason_push': '',
      'failure_reason_email': '',
      'title_snapshot': title.trim(),
      'body_snapshot': body.trim(),
      'context_type': contextType.trim(),
      'context_id': contextId.trim(),
      'reference_type': contextType.trim(),
      'reference_id': contextId.trim(),
      'created_at': now,
      'updated_at': now,
    });

    await batch.commit();
    return notificationRef.id;
  }

  Future<void> createBookingConfirmedNotification({
    required String userUid,
    required String employeeNumber,
    required String employeeName,
    required String email,
    required String reservationId,
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final mealLabel = _mealLabel(mealType);
    final dateLabel = _formatDate(reservationDate);

    await createTransactionalNotification(
      type: 'meal_booking_confirmed',
      title: 'Meal Booking Confirmed',
      body: 'Your $mealLabel booking for $dateLabel has been confirmed.',
      userUid: userUid,
      employeeNumber: employeeNumber,
      employeeName: employeeName,
      email: email,
      contextType: 'reservation',
      contextId: reservationId,
      triggerSource: 'reservation_service',
    );
  }

  Future<void> createBookingCancelledNotification({
    required String userUid,
    required String employeeNumber,
    required String employeeName,
    required String email,
    required String reservationId,
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final mealLabel = _mealLabel(mealType);
    final dateLabel = _formatDate(reservationDate);

    await createTransactionalNotification(
      type: 'meal_booking_cancelled',
      title: 'Meal Booking Cancelled',
      body: 'Your $mealLabel booking for $dateLabel has been cancelled.',
      userUid: userUid,
      employeeNumber: employeeNumber,
      employeeName: employeeName,
      email: email,
      contextType: 'reservation',
      contextId: reservationId,
      triggerSource: 'reservation_service',
    );
  }

  Future<void> createMealIssuedNotification({
    required String userUid,
    required String employeeNumber,
    required String employeeName,
    required String email,
    required String reservationId,
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final mealLabel = _mealLabel(mealType);
    final dateLabel = _formatDate(reservationDate);

    await createTransactionalNotification(
      type: 'meal_issued',
      title: 'Meal Issued',
      body: 'Your $mealLabel booking for $dateLabel has been issued.',
      userUid: userUid,
      employeeNumber: employeeNumber,
      employeeName: employeeName,
      email: email,
      contextType: 'meal_issuance',
      contextId: reservationId,
      triggerSource: 'meal_issuance_service',
    );
  }

  Future<List<_NotificationTarget>> _resolveAdministrativeTargets({
    required String targetType,
    required List<String> targetUserUids,
  }) async {
    if (targetType == 'single_user' || targetType == 'selected_users') {
      if (targetUserUids.isEmpty) {
        return <_NotificationTarget>[];
      }

      final allTargets = await _loadActiveUserTargets();
      final wanted = targetUserUids.map((e) => e.trim()).toSet();

      return allTargets
          .where((target) => wanted.contains(target.userUid))
          .toList(growable: false);
    }

    return _loadActiveUserTargets();
  }

  Future<List<_NotificationTarget>> _loadActiveUserTargets() async {
    final usersSnapshot = await _usersRef.get();
    final profilesSnapshot = await _profilesRef.get();

    final Map<String, Map<String, dynamic>> profilesByAuthUid =
        <String, Map<String, dynamic>>{};
    final Map<String, Map<String, dynamic>> profilesByEmployeeNumber =
        <String, Map<String, dynamic>>{};

    for (final doc in profilesSnapshot.docs) {
      final data = doc.data();

      final authUid = _readString(data['auth_uid']);
      final employeeNumber = _readString(data['employee_number']);

      if (authUid.isNotEmpty && !profilesByAuthUid.containsKey(authUid)) {
        profilesByAuthUid[authUid] = data;
      }

      if (employeeNumber.isNotEmpty &&
          !profilesByEmployeeNumber.containsKey(employeeNumber)) {
        profilesByEmployeeNumber[employeeNumber] = data;
      }
    }

    final List<_NotificationTarget> targets = <_NotificationTarget>[];
    final Set<String> seenUserUids = <String>{};

    for (final doc in usersSnapshot.docs) {
      final userData = doc.data();

      final userUid = _readString(
        userData['uid'],
        fallback: doc.id,
      );
      final employeeNumber = _readString(userData['employee_number']);

      if (userUid.isEmpty || employeeNumber.isEmpty) {
        continue;
      }

      final profileData =
          profilesByAuthUid[userUid] ?? profilesByEmployeeNumber[employeeNumber];

      final approved = _looksApproved(
        userData: userData,
        profileData: profileData,
      );
      final active = _looksActive(
        userData: userData,
        profileData: profileData,
      );

      if (!approved || !active) {
        continue;
      }

      if (seenUserUids.contains(userUid)) {
        continue;
      }

      seenUserUids.add(userUid);

      final employeeName = _firstNonEmptyString([
        userData['employee_name'],
        userData['name'],
        userData['display_name'],
        userData['full_name'],
        profileData?['employee_name'],
        profileData?['name'],
        profileData?['display_name'],
        profileData?['full_name'],
      ]);

      final email = _firstNonEmptyString([
        userData['email'],
        profileData?['email'],
      ]);

      targets.add(
        _NotificationTarget(
          userUid: userUid,
          employeeNumber: employeeNumber,
          employeeName: employeeName,
          email: email,
        ),
      );
    }

    targets.sort((a, b) => a.employeeNumber.compareTo(b.employeeNumber));
    return targets;
  }

  bool _looksApproved({
    required Map<String, dynamic> userData,
    Map<String, dynamic>? profileData,
  }) {
    final userActive = userData['is_active'] == true;
    final profileActive = profileData?['is_active'] == true;

    final userStatus = _readString(userData['status']).toLowerCase();
    final profileStatus = _readString(profileData?['status']).toLowerCase();

    if (userActive || profileActive) {
      return true;
    }

    return userStatus == 'approved' || profileStatus == 'approved';
  }

  bool _looksActive({
    required Map<String, dynamic> userData,
    Map<String, dynamic>? profileData,
  }) {
    final userActive = userData['is_active'] == true;
    final profileActive = profileData?['is_active'] == true;

    final userStatus = _readString(userData['status']).toLowerCase();
    final profileStatus = _readString(profileData?['status']).toLowerCase();

    if (userActive || profileActive) {
      return true;
    }

    return userStatus == 'approved' || profileStatus == 'approved';
  }

  String _normalizeTargetType(String targetType) {
    final value = targetType.trim().toLowerCase();

    if (value.isEmpty) {
      return 'all_active_employees';
    }

    if (value == 'all_employees') {
      return 'all_active_employees';
    }

    if (value == 'selected_users') {
      return 'selected_users';
    }

    if (value == 'single_user') {
      return 'single_user';
    }

    return value;
  }

  String _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = _readString(value);
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  String _mealLabel(String mealType) {
    switch (mealType.trim().toLowerCase()) {
      case 'breakfast':
        return 'breakfast';
      case 'lunch':
        return 'lunch';
      case 'dinner':
        return 'dinner';
      default:
        return mealType.trim().toLowerCase();
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  String _readString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
    return fallback.trim();
  }
}

class _NotificationTarget {
  const _NotificationTarget({
    required this.userUid,
    required this.employeeNumber,
    required this.employeeName,
    required this.email,
  });

  final String userUid;
  final String employeeNumber;
  final String employeeName;
  final String email;
}
