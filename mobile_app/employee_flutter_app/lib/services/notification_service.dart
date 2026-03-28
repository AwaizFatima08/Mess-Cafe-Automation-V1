import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('notifications');

  CollectionReference<Map<String, dynamic>> get _deliveriesRef =>
      _firestore.collection('notification_deliveries');

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

    await docRef.update({
      'in_app_status': 'read',
      'read_at': Timestamp.now(),
      'updated_at': Timestamp.now(),
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

    await docRef.update({
      'popup_acknowledged_at': Timestamp.now(),
      'updated_at': Timestamp.now(),
      if (currentStatus == 'pending') 'in_app_status': 'visible',
      if (currentStatus == 'pending') 'in_app_visible_at': Timestamp.now(),
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
    final docRef = _notificationsRef.doc();
    final now = Timestamp.now();

    final normalizedTargets = (targetUserUids ?? <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final payload = <String, dynamic>{
      'notification_id': docRef.id,
      'notification_layer': 'administrative',
      'type': type.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'short_message': title.trim(),
      'status': status.trim().isEmpty ? 'published' : status.trim(),
      'priority': priority.trim().isEmpty ? 'normal' : priority.trim(),
      'target_type': targetType.trim().isEmpty ? 'all_employees' : targetType,
      'target_user_uid': null,
      'target_user_uids': normalizedTargets,
      'send_in_app': sendInApp,
      'send_push': sendPush,
      'send_email': sendEmail,
      'created_by_uid': createdByUid.trim(),
      'created_by_name': createdByName?.trim() ?? '',
      'trigger_source': triggerSource.trim().isEmpty
          ? 'admin_manual'
          : triggerSource.trim(),
      'requires_review': requiresReview,
      'review_status':
          reviewStatus.trim().isEmpty ? 'approved' : reviewStatus.trim(),
      'reviewed_by_uid': reviewedByUid?.trim() ?? '',
      'reviewed_at':
          requiresReview && reviewStatus.trim().toLowerCase() == 'approved'
              ? now
              : null,
      'context_type': contextType?.trim() ?? '',
      'context_id': contextId?.trim() ?? '',
      'email_subject': title.trim(),
      'email_body': body.trim(),
      'push_title': title.trim(),
      'push_body': body.trim(),
      'publish_at': publishAt,
      'published_at': status.trim().toLowerCase() == 'draft' ? null : now,
      'expires_at': expiresAt,
      'delivery_count_total': 0,
      'delivery_count_in_app': 0,
      'delivery_count_push_sent': 0,
      'delivery_count_push_failed': 0,
      'delivery_count_email_sent': 0,
      'delivery_count_email_failed': 0,
      'created_at': now,
      'updated_at': now,
    };

    await docRef.set(payload);
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
      'target_user_uid': userUid.trim(),
      'target_user_uids': <String>[],
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
      'user_uid': userUid.trim(),
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
}
