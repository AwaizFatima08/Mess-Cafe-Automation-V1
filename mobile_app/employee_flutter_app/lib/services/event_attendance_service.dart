import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event_attendance_response_model.dart';
import '../models/event_attendance_summary_model.dart';
import '../models/event_model.dart';
import '../models/event_note_template_model.dart';

class EventAttendanceService {
  EventAttendanceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection(EventModel.collectionName);

  CollectionReference<Map<String, dynamic>> get _notesRef =>
      _firestore.collection(EventNoteTemplateModel.collectionName);

  CollectionReference<Map<String, dynamic>> get _responsesRef =>
      _firestore.collection(EventAttendanceResponseModel.collectionName);

  CollectionReference<Map<String, dynamic>> get _summariesRef =>
      _firestore.collection(EventAttendanceSummaryModel.collectionName);

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _profilesRef =>
      _firestore.collection('employee_profiles');

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('notifications');

  CollectionReference<Map<String, dynamic>> get _notificationDeliveriesRef =>
      _firestore.collection('notification_deliveries');

  // ---------------------------------------------------------------------------
  // EVENT CRUD
  // ---------------------------------------------------------------------------

  Future<String> createEvent(EventModel event) async {
    final String documentId = event.documentId.trim().isNotEmpty
        ? event.documentId.trim()
        : EventModel.buildEventDocumentId(
            slug: EventModel.buildSuggestedSlug(
              title: event.title,
              eventDate: event.startDateTime ?? event.eventDateTime,
            ),
          );

    final Timestamp now = Timestamp.now();

    final EventModel normalizedEvent = event.copyWith(
      documentId: documentId,
      eventId: documentId,
      status: EventModel.statusDraft,
      createdAt: event.createdAt ?? now,
      updatedAt: now,
      publishedAt: null,
      closedAt: null,
      cancelledAt: null,
      householdsResponded: event.householdsResponded,
      householdsPending: event.householdsPending,
      grandTotalAttendees: event.grandTotalAttendees,
    );

    await _eventsRef.doc(documentId).set(normalizedEvent.toMap());
    return documentId;
  }

  Future<void> updateEvent(EventModel event) async {
    _validateEventDocumentId(event.documentId);

    final Timestamp now = Timestamp.now();

    final EventModel existing = await getEventById(event.documentId) ??
        (throw Exception('Event not found: ${event.documentId}'));

    if (existing.isClosed || existing.isCancelled) {
      throw Exception('Closed or cancelled events cannot be edited.');
    }

    final EventModel normalizedEvent = event.copyWith(
      documentId: existing.documentId,
      eventId: existing.eventId,
      createdAt: existing.createdAt,
      publishedAt: existing.publishedAt,
      closedAt: existing.closedAt,
      cancelledAt: existing.cancelledAt,
      updatedAt: now,
    );

    await _eventsRef.doc(existing.documentId).update(normalizedEvent.toMap());
  }

  Future<void> publishEvent(String eventId) async {
    _validateEventDocumentId(eventId);

    final DocumentReference<Map<String, dynamic>> eventDoc =
        _eventsRef.doc(eventId);
    final DocumentSnapshot<Map<String, dynamic>> eventSnapshot =
        await eventDoc.get();

    if (!eventSnapshot.exists) {
      throw Exception('Event not found: $eventId');
    }

    final EventModel event = EventModel.fromDocument(eventSnapshot);

    if (event.isCancelled) {
      throw Exception('Cancelled event cannot be published.');
    }

    if (event.isClosed) {
      throw Exception('Closed event cannot be published.');
    }

    final Timestamp now = Timestamp.now();
    final List<EventNoteSnapshot> notesSnapshot = event.notesSnapshot.isNotEmpty
        ? event.notesSnapshot
        : await _buildNotesSnapshot(event.selectedNoteIds);

    final int householdsPending = event.targetCountEstimate > 0
        ? event.targetCountEstimate - event.householdsResponded
        : 0;

    await eventDoc.update(<String, dynamic>{
      'status': EventModel.statusPublished,
      'updated_at': now,
      'published_at': now,
      'notes_snapshot': notesSnapshot.map((e) => e.toMap()).toList(),
      'households_pending': householdsPending < 0 ? 0 : householdsPending,
    });

    final EventModel publishedEvent = event.copyWith(
      status: EventModel.statusPublished,
      updatedAt: now,
      publishedAt: now,
      notesSnapshot: notesSnapshot,
      householdsPending: householdsPending < 0 ? 0 : householdsPending,
    );

    await _createEventInvitationNotifications(publishedEvent);
    await rebuildEventSummary(eventId);
  }

  Future<void> closeEvent(String eventId) async {
    _validateEventDocumentId(eventId);

    final DocumentReference<Map<String, dynamic>> eventDoc =
        _eventsRef.doc(eventId);
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await eventDoc.get();

    if (!snapshot.exists) {
      throw Exception('Event not found: $eventId');
    }

    final EventModel event = EventModel.fromDocument(snapshot);

    if (event.isCancelled) {
      throw Exception('Cancelled event cannot be closed.');
    }

    final Timestamp now = Timestamp.now();

    await eventDoc.update(<String, dynamic>{
      'status': EventModel.statusClosed,
      'updated_at': now,
      'closed_at': now,
      'report_locked': true,
    });

    await _lockAllResponsesForEvent(eventId);
    await rebuildEventSummary(eventId);
  }

  Future<void> cancelEvent(String eventId) async {
    _validateEventDocumentId(eventId);

    final DocumentReference<Map<String, dynamic>> eventDoc =
        _eventsRef.doc(eventId);
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await eventDoc.get();

    if (!snapshot.exists) {
      throw Exception('Event not found: $eventId');
    }

    final EventModel event = EventModel.fromDocument(snapshot);

    if (event.isClosed) {
      throw Exception('Closed event cannot be cancelled.');
    }

    final Timestamp now = Timestamp.now();

    await eventDoc.update(<String, dynamic>{
      'status': EventModel.statusCancelled,
      'updated_at': now,
      'cancelled_at': now,
      'report_locked': true,
    });

    await _lockAllResponsesForEvent(eventId);
  }

  Future<EventModel?> getEventById(String eventId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _eventsRef.doc(eventId).get();

    if (!snapshot.exists) {
      return null;
    }

    return EventModel.fromDocument(snapshot);
  }

  Stream<List<EventModel>> watchAdminEvents() {
    return _eventsRef.orderBy('created_at', descending: true).snapshots().map(
      (snapshot) {
        final List<EventModel> items =
            snapshot.docs.map(EventModel.fromDocument).toList();
        items.sort(_sortEventsForAdmin);
        return items;
      },
    );
  }

  Stream<List<EventModel>> watchEmployeeVisibleEvents() {
    return _eventsRef
        .where('show_on_employee_dashboard', isEqualTo: true)
        .where('is_deleted_soft', isEqualTo: false)
        .snapshots()
        .map(
      (snapshot) {
        final List<EventModel> items = snapshot.docs
            .map(EventModel.fromDocument)
            .where(
              (event) =>
                  event.status == EventModel.statusPublished ||
                  event.status == EventModel.statusClosed,
            )
            .toList();

        items.sort(_sortEventsForEmployee);
        return items;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // NOTE TEMPLATES
  // ---------------------------------------------------------------------------

  Future<List<EventNoteTemplateModel>> getActiveNoteTemplates() async {
    QuerySnapshot<Map<String, dynamic>> query = await _notesRef.get();

    if (query.docs.isEmpty) {
      await seedDefaultEventNotes();
      query = await _notesRef.get();
    }

    final List<EventNoteTemplateModel> items = query.docs
        .map(EventNoteTemplateModel.fromDocument)
        .where((note) => note.isActive && note.isVisible && note.isValid)
        .toList(growable: true);

    items.sort((a, b) {
      final int orderCompare = a.displayOrder.compareTo(b.displayOrder);
      if (orderCompare != 0) {
        return orderCompare;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return List<EventNoteTemplateModel>.unmodifiable(items);
  }

  Future<void> seedDefaultEventNotes() async {
    final QuerySnapshot<Map<String, dynamic>> existing =
        await _notesRef.limit(1).get();

    if (existing.docs.isNotEmpty) {
      return;
    }

    final Timestamp now = Timestamp.now();

    final List<Map<String, dynamic>> defaultNotes = <Map<String, dynamic>>[
      <String, dynamic>{
        'document_id': 'note_001',
        'template_id': 'note_001',
        'title': 'Permanent Resident Guest Definition',
        'body':
            'Permanent resident guests include family members who have been registered as permanent resident guests in company record with resident cards issued.',
        'display_order': 1,
      },
      <String, dynamic>{
        'document_id': 'note_002',
        'template_id': 'note_002',
        'title': 'Visiting Guest Charges',
        'body': 'Visiting guests will be charged as per actual cost.',
        'display_order': 2,
      },
      <String, dynamic>{
        'document_id': 'note_003',
        'template_id': 'note_003',
        'title': 'Maid / Servant Seating',
        'body':
            'Maids are not allowed in the event arena. Separate sitting arrangements will be made for maids and servants.',
        'display_order': 3,
      },
      <String, dynamic>{
        'document_id': 'note_004',
        'template_id': 'note_004',
        'title': 'Dress Code',
        'body': 'Please follow the given dress code.',
        'display_order': 4,
      },
      <String, dynamic>{
        'document_id': 'note_005',
        'template_id': 'note_005',
        'title': 'Arrival Timing',
        'body':
            'Please arrive 10 minutes before starting time of event and be seated before arrival of chief guest.',
        'display_order': 5,
      },
      <String, dynamic>{
        'document_id': 'note_006',
        'template_id': 'note_006',
        'title': 'Entry Subject to Attendance',
        'body': 'Guests without attendance may be returned from the reception.',
        'display_order': 6,
      },
    ];

    final WriteBatch batch = _firestore.batch();

    for (final Map<String, dynamic> item in defaultNotes) {
      final String docId = item['document_id'] as String;
      batch.set(_notesRef.doc(docId), <String, dynamic>{
        'template_id': item['template_id'],
        'title': item['title'],
        'body': item['body'],
        'is_active': true,
        'is_visible': true,
        'display_order': item['display_order'],
        'created_at': now,
        'updated_at': now,
      });
    }

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // RESPONSES
  // ---------------------------------------------------------------------------

  Future<void> submitAttendanceResponse(
    EventAttendanceResponseModel response,
  ) async {
    final String currentUid = _auth.currentUser?.uid.trim() ?? '';
    if (currentUid.isEmpty) {
      throw Exception('No authenticated user found.');
    }

    if (response.userUid.trim().isNotEmpty &&
        response.userUid.trim() != currentUid) {
      throw Exception('Response UID does not match authenticated user.');
    }

    final String documentId = EventAttendanceResponseModel.buildDocumentId(
      eventId: response.eventId,
      employeeNumber: response.employeeNumber,
    );

    final DocumentReference<Map<String, dynamic>> eventRef =
        _eventsRef.doc(response.eventId);
    final DocumentReference<Map<String, dynamic>> responseRef =
        _responsesRef.doc(documentId);
    final DocumentReference<Map<String, dynamic>> summaryRef =
        _summariesRef.doc(response.eventId);

    bool requiresRebuild = false;

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> eventSnapshot =
          await transaction.get(eventRef);
      final DocumentSnapshot<Map<String, dynamic>> existingResponseSnapshot =
          await transaction.get(responseRef);
      final DocumentSnapshot<Map<String, dynamic>> summarySnapshot =
          await transaction.get(summaryRef);

      if (!eventSnapshot.exists) {
        throw Exception('Event not found: ${response.eventId}');
      }

      final EventModel event = EventModel.fromDocument(eventSnapshot);

      if (!event.isResponseWindowOpen()) {
        throw Exception('Attendance response window is closed.');
      }

      EventAttendanceResponseModel? oldResponse;
      if (existingResponseSnapshot.exists) {
        oldResponse =
            EventAttendanceResponseModel.fromDocument(existingResponseSnapshot);

        if (oldResponse.submissionLocked) {
          throw Exception('This attendance response is locked.');
        }
      }

      final Map<String, int> normalizedCounts =
          _normalizeResponseCounts(response);

      final int computedTotal =
          EventAttendanceResponseModel.calculateTotal(normalizedCounts);

      final Timestamp now = Timestamp.now();

      final EventAttendanceResponseModel newResponse =
          EventAttendanceResponseModel(
        documentId: documentId,
        eventId: response.eventId,
        userUid: currentUid,
        employeeNumber: response.employeeNumber,
        employeeName: response.employeeName,
        department: response.department,
        designation: response.designation,
        attendanceStatus: response.attendanceStatus,
        submittedAt: oldResponse?.submittedAt ?? now,
        updatedAt: now,
        submissionLocked: false,
        counts: normalizedCounts,
        totalAttendees: computedTotal,
        employeeNote: response.employeeNote,
        responseVersion: (oldResponse?.responseVersion ?? 0) + 1,
        source: response.source.trim().isEmpty
            ? 'mobile_app'
            : response.source.trim(),
        rawData: response.rawData,
      );

      if (!summarySnapshot.exists) {
        requiresRebuild = true;

        transaction.set(
          responseRef,
          newResponse.toMap(),
          SetOptions(merge: true),
        );

        return;
      }

      final EventAttendanceSummaryModel summary =
          EventAttendanceSummaryModel.fromDocument(summarySnapshot);

      final _SummaryComputation updated = _applyResponseDeltaToSummary(
        summary: summary,
        event: event,
        oldResponse: oldResponse,
        newResponse: newResponse,
      );

      transaction.set(
        responseRef,
        newResponse.toMap(),
        SetOptions(merge: true),
      );

      transaction.set(
        summaryRef,
        updated.summary.toMap(),
        SetOptions(merge: true),
      );

      transaction.update(eventRef, <String, dynamic>{
        'households_responded': updated.summary.householdsResponded,
        'households_pending': updated.summary.householdsPending < 0
            ? 0
            : updated.summary.householdsPending,
        'grand_total_attendees': updated.summary.grandTotal,
        'updated_at': updated.summary.lastAggregatedAt,
      });
    });

    if (requiresRebuild) {
      await rebuildEventSummary(response.eventId);
    }
  }

  Future<EventAttendanceResponseModel?> getEmployeeResponse(
    String eventId,
    String employeeNumber,
  ) async {
    final String documentId = EventAttendanceResponseModel.buildDocumentId(
      eventId: eventId,
      employeeNumber: employeeNumber,
    );

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _responsesRef.doc(documentId).get();

    if (!snapshot.exists) {
      return null;
    }

    return EventAttendanceResponseModel.fromDocument(snapshot);
  }

  Stream<EventAttendanceResponseModel?> watchEmployeeResponse(
    String eventId,
    String employeeNumber,
  ) {
    final String documentId = EventAttendanceResponseModel.buildDocumentId(
      eventId: eventId,
      employeeNumber: employeeNumber,
    );

    return _responsesRef.doc(documentId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return EventAttendanceResponseModel.fromDocument(snapshot);
    });
  }

  Stream<List<EventAttendanceResponseModel>> watchEventResponses(
    String eventId,
  ) {
    return _responsesRef
        .where('event_id', isEqualTo: eventId)
        .snapshots()
        .map((snapshot) {
      final List<EventAttendanceResponseModel> items = snapshot.docs
          .map(EventAttendanceResponseModel.fromDocument)
          .toList(growable: false);

      items.sort((a, b) => a.employeeNumber.compareTo(b.employeeNumber));
      return items;
    });
  }

  // ---------------------------------------------------------------------------
  // SUMMARIES
  // ---------------------------------------------------------------------------

  Future<EventAttendanceSummaryModel> rebuildEventSummary(String eventId) async {
    final EventModel event = await getEventById(eventId) ??
        (throw Exception('Event not found: $eventId'));

    final QuerySnapshot<Map<String, dynamic>> query =
        await _responsesRef.where('event_id', isEqualTo: eventId).get();

    int householdsResponded = 0;
    int householdsAttending = 0;
    int householdsNotAttending = 0;

    final Map<String, int> categoryTotals = <String, int>{
      for (final String key in EventAttendanceSummaryModel.categoryKeys) key: 0,
    };

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in query.docs) {
      final EventAttendanceResponseModel response =
          EventAttendanceResponseModel.fromDocument(doc);

      householdsResponded++;

      if (response.attendanceStatus ==
          EventAttendanceResponseModel.statusAttending) {
        householdsAttending++;
      } else {
        householdsNotAttending++;
      }

      for (final String key in EventAttendanceSummaryModel.categoryKeys) {
        categoryTotals[key] =
            (categoryTotals[key] ?? 0) + (response.counts[key] ?? 0);
      }
    }

    final int householdsPending = event.targetCountEstimate > 0
        ? event.targetCountEstimate - householdsResponded
        : 0;

    int grandTotal = 0;
    for (final String key in EventAttendanceSummaryModel.categoryKeys) {
      grandTotal += categoryTotals[key] ?? 0;
    }

    final Timestamp now = Timestamp.now();

    final EventAttendanceSummaryModel summary = EventAttendanceSummaryModel(
      documentId: eventId,
      eventId: eventId,
      lastAggregatedAt: now,
      householdsResponded: householdsResponded,
      householdsPending: householdsPending < 0 ? 0 : householdsPending,
      householdsAttending: householdsAttending,
      householdsNotAttending: householdsNotAttending,
      categoryTotals: categoryTotals,
      grandTotal: grandTotal,
      rawData: const <String, dynamic>{},
    );

    final WriteBatch batch = _firestore.batch();

    batch.set(
      _summariesRef.doc(eventId),
      summary.toMap(),
      SetOptions(merge: true),
    );

    batch.update(_eventsRef.doc(eventId), <String, dynamic>{
      'households_responded': householdsResponded,
      'households_pending': householdsPending < 0 ? 0 : householdsPending,
      'grand_total_attendees': grandTotal,
      'updated_at': now,
    });

    await batch.commit();

    return summary;
  }

  Future<EventAttendanceSummaryModel?> getEventSummary(String eventId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _summariesRef.doc(eventId).get();

    if (!snapshot.exists) {
      return null;
    }

    return EventAttendanceSummaryModel.fromDocument(snapshot);
  }

  Stream<EventAttendanceSummaryModel?> watchEventSummary(String eventId) {
    return _summariesRef.doc(eventId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return EventAttendanceSummaryModel.fromDocument(snapshot);
    });
  }

  // ---------------------------------------------------------------------------
  // REPORT HELPERS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getPendingEmployees(String eventId) async {
    final EventModel event = await getEventById(eventId) ??
        (throw Exception('Event not found: $eventId'));

    if (event.targetScope.trim() != 'all_active_employees') {
      return <Map<String, dynamic>>[];
    }

    final List<_NotificationTarget> activeUsers = await _loadActiveUserTargets();
    final QuerySnapshot<Map<String, dynamic>> responses =
        await _responsesRef.where('event_id', isEqualTo: eventId).get();

    final Set<String> respondedEmployeeNumbers = responses.docs
        .map(EventAttendanceResponseModel.fromDocument)
        .map((response) => response.employeeNumber.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();

    final List<Map<String, dynamic>> pending = activeUsers
        .where((user) {
          return !respondedEmployeeNumbers
              .contains(user.employeeNumber.trim().toLowerCase());
        })
        .map((user) {
          return <String, dynamic>{
            'user_uid': user.userUid,
            'employee_number': user.employeeNumber,
            'employee_name': user.employeeName,
            'email': user.email,
          };
        })
        .toList(growable: false);

    pending.sort((a, b) {
      final String left = (a['employee_number'] ?? '').toString();
      final String right = (b['employee_number'] ?? '').toString();
      return left.compareTo(right);
    });

    return pending;
  }

  // ---------------------------------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------------------------------

  Map<String, int> _normalizeResponseCounts(
    EventAttendanceResponseModel response,
  ) {
    final Map<String, int> normalizedCounts = <String, int>{
      for (final String key in EventAttendanceResponseModel.categoryKeys)
        key: 0,
    };

    for (final String key in EventAttendanceResponseModel.categoryKeys) {
      normalizedCounts[key] = response.counts[key] ?? 0;
    }

    if (response.attendanceStatus ==
        EventAttendanceResponseModel.statusAttending) {
      normalizedCounts['employee'] = 1;
    } else {
      for (final String key in EventAttendanceResponseModel.categoryKeys) {
        normalizedCounts[key] = 0;
      }
    }

    return normalizedCounts;
  }

  _SummaryComputation _applyResponseDeltaToSummary({
    required EventAttendanceSummaryModel summary,
    required EventModel event,
    required EventAttendanceResponseModel? oldResponse,
    required EventAttendanceResponseModel newResponse,
  }) {
    int householdsResponded = summary.householdsResponded;
    int householdsAttending = summary.householdsAttending;
    int householdsNotAttending = summary.householdsNotAttending;

    final Map<String, int> categoryTotals = <String, int>{
      for (final String key in EventAttendanceSummaryModel.categoryKeys)
        key: summary.categoryTotals[key] ?? 0,
    };

    if (oldResponse == null) {
      householdsResponded += 1;
    } else {
      if (oldResponse.attendanceStatus ==
          EventAttendanceResponseModel.statusAttending) {
        householdsAttending -= 1;
      } else {
        householdsNotAttending -= 1;
      }

      for (final String key in EventAttendanceSummaryModel.categoryKeys) {
        categoryTotals[key] =
            (categoryTotals[key] ?? 0) - (oldResponse.counts[key] ?? 0);
      }
    }

    if (newResponse.attendanceStatus ==
        EventAttendanceResponseModel.statusAttending) {
      householdsAttending += 1;
    } else {
      householdsNotAttending += 1;
    }

    for (final String key in EventAttendanceSummaryModel.categoryKeys) {
      categoryTotals[key] =
          (categoryTotals[key] ?? 0) + (newResponse.counts[key] ?? 0);

      if ((categoryTotals[key] ?? 0) < 0) {
        categoryTotals[key] = 0;
      }
    }

    if (householdsResponded < 0) {
      householdsResponded = 0;
    }
    if (householdsAttending < 0) {
      householdsAttending = 0;
    }
    if (householdsNotAttending < 0) {
      householdsNotAttending = 0;
    }

    int grandTotal = 0;
    for (final String key in EventAttendanceSummaryModel.categoryKeys) {
      grandTotal += categoryTotals[key] ?? 0;
    }

    final int householdsPending = event.targetCountEstimate > 0
        ? event.targetCountEstimate - householdsResponded
        : 0;

    final Timestamp now = Timestamp.now();

    final EventAttendanceSummaryModel updatedSummary =
        EventAttendanceSummaryModel(
      documentId: summary.documentId,
      eventId: summary.eventId,
      lastAggregatedAt: now,
      householdsResponded: householdsResponded,
      householdsPending: householdsPending < 0 ? 0 : householdsPending,
      householdsAttending: householdsAttending,
      householdsNotAttending: householdsNotAttending,
      categoryTotals: categoryTotals,
      grandTotal: grandTotal,
      rawData: summary.rawData,
    );

    return _SummaryComputation(
      summary: updatedSummary,
    );
  }

  Future<List<EventNoteSnapshot>> _buildNotesSnapshot(
    List<String> noteIds,
  ) async {
    if (noteIds.isEmpty) {
      return const <EventNoteSnapshot>[];
    }

    final List<EventNoteSnapshot> snapshots = <EventNoteSnapshot>[];

    for (final String rawId in noteIds) {
      final String noteId = rawId.trim();
      if (noteId.isEmpty) {
        continue;
      }

      final DocumentSnapshot<Map<String, dynamic>> noteDoc =
          await _notesRef.doc(noteId).get();

      if (!noteDoc.exists) {
        continue;
      }

      final EventNoteTemplateModel note =
          EventNoteTemplateModel.fromDocument(noteDoc);

      snapshots.add(
        EventNoteSnapshot(
          noteId: note.documentId,
          title: note.title,
          body: note.body,
        ),
      );
    }

    return snapshots;
  }

  Future<void> _lockAllResponsesForEvent(String eventId) async {
    final QuerySnapshot<Map<String, dynamic>> query =
        await _responsesRef.where('event_id', isEqualTo: eventId).get();

    if (query.docs.isEmpty) {
      return;
    }

    final WriteBatch batch = _firestore.batch();
    final Timestamp now = Timestamp.now();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in query.docs) {
      batch.update(doc.reference, <String, dynamic>{
        'submission_locked': true,
        'updated_at': now,
      });
    }

    await batch.commit();
  }

  Future<void> _createEventInvitationNotifications(EventModel event) async {
    final List<_NotificationTarget> targets = await _loadActiveUserTargets();

    if (targets.isEmpty) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> notificationDoc =
        _notificationsRef.doc();
    final Timestamp now = Timestamp.now();

    final String title = event.title.trim().isEmpty
        ? 'New Event Invitation'
        : event.title.trim();

    final String body = _buildNotificationBody(event);

    final WriteBatch batch = _firestore.batch();

    batch.set(notificationDoc, <String, dynamic>{
      'notification_id': notificationDoc.id,
      'notification_layer': 'administrative',
      'type': 'event_invitation',
      'title': title,
      'body': body,
      'short_message': title,
      'status': 'published',
      'priority': 'normal',
      'target_type': event.targetScope.trim().isEmpty
          ? 'all_active_employees'
          : event.targetScope.trim(),
      'target_user_uid': null,
      'target_user_uids': targets.map((e) => e.userUid).toList(),
      'send_in_app': true,
      'send_push': false,
      'send_email': false,
      'created_by_uid': '',
      'created_by_name': '',
      'trigger_source': 'event_attendance_service',
      'requires_review': false,
      'review_status': 'not_required',
      'reviewed_by_uid': '',
      'reviewed_at': null,
      'context_type': 'event',
      'context_id': event.eventId,
      'reference_type': 'event',
      'reference_id': event.eventId,
      'show_popup_on_publish': event.showPopupOnPublish,
      'email_subject': title,
      'email_body': body,
      'push_title': title,
      'push_body': body,
      'publish_at': now,
      'published_at': now,
      'expires_at': null,
      'delivery_count_total': targets.length,
      'delivery_count_in_app': targets.length,
      'delivery_count_push_sent': 0,
      'delivery_count_push_failed': 0,
      'delivery_count_email_sent': 0,
      'delivery_count_email_failed': 0,
      'created_at': now,
      'updated_at': now,
    });

    for (final _NotificationTarget target in targets) {
      final DocumentReference<Map<String, dynamic>> deliveryDoc =
          _notificationDeliveriesRef.doc();

      batch.set(deliveryDoc, <String, dynamic>{
        'delivery_id': deliveryDoc.id,
        'notification_id': notificationDoc.id,
        'user_uid': target.userUid,
        'employee_number': target.employeeNumber,
        'employee_name': target.employeeName,
        'email': target.email,
        'notification_layer': 'administrative',
        'type': 'event_invitation',
        'in_app_enabled': true,
        'push_enabled': false,
        'email_enabled': false,
        'in_app_status': event.showPopupOnPublish ? 'pending' : 'visible',
        'push_status': 'skipped',
        'email_status': 'skipped',
        'push_sent_at': null,
        'email_sent_at': null,
        'in_app_visible_at': event.showPopupOnPublish ? null : now,
        'read_at': null,
        'archived_at': null,
        'popup_acknowledged_at': null,
        'failure_reason_push': '',
        'failure_reason_email': '',
        'title_snapshot': title,
        'body_snapshot': body,
        'context_type': 'event',
        'context_id': event.eventId,
        'reference_type': 'event',
        'reference_id': event.eventId,
        'created_at': now,
        'updated_at': now,
      });
    }

    await batch.commit();
  }

  String _buildNotificationBody(EventModel event) {
    final String cutoffText = event.responseCutoffDateTime == null
        ? 'Please mark attendance.'
        : 'Please mark attendance before ${_formatDateTime(event.responseCutoffDateTime!)}.';

    if (event.venue.trim().isEmpty) {
      return cutoffText;
    }

    return '${event.venue.trim()} — $cutoffText';
  }

  Future<List<_NotificationTarget>> _loadActiveUserTargets() async {
    final QuerySnapshot<Map<String, dynamic>> usersSnapshot =
        await _usersRef.get();
    final QuerySnapshot<Map<String, dynamic>> profilesSnapshot =
        await _profilesRef.get();

    final Map<String, Map<String, dynamic>> profilesByAuthUid =
        <String, Map<String, dynamic>>{};
    final Map<String, Map<String, dynamic>> profilesByEmployeeNumber =
        <String, Map<String, dynamic>>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in profilesSnapshot.docs) {
      final Map<String, dynamic> data = doc.data();

      final String authUid = _readString(data['auth_uid']);
      final String employeeNumber = _readString(data['employee_number']);

      if (authUid.isNotEmpty && !profilesByAuthUid.containsKey(authUid)) {
        profilesByAuthUid[authUid] = data;
      }

      if (employeeNumber.isNotEmpty &&
          !profilesByEmployeeNumber.containsKey(employeeNumber)) {
        profilesByEmployeeNumber[employeeNumber] = data;
      }
    }

    final List<_NotificationTarget> targets = <_NotificationTarget>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in usersSnapshot.docs) {
      final Map<String, dynamic> userData = doc.data();

      final String userUid = _readString(
        userData['uid'],
        fallback: doc.id,
      );

      final String employeeNumber = _readString(userData['employee_number']);

      if (userUid.isEmpty || employeeNumber.isEmpty) {
        continue;
      }

      final Map<String, dynamic>? profileData =
          profilesByAuthUid[userUid] ?? profilesByEmployeeNumber[employeeNumber];

      final bool approved = _looksApproved(
        userData: userData,
        profileData: profileData,
      );
      final bool active = _looksActive(
        userData: userData,
        profileData: profileData,
      );

      if (!approved || !active) {
        continue;
      }

      final String employeeName = _firstNonEmptyString([
        userData['employee_name'],
        userData['name'],
        userData['display_name'],
        userData['full_name'],
        profileData?['employee_name'],
        profileData?['name'],
        profileData?['display_name'],
        profileData?['full_name'],
      ]);

      final String email = _firstNonEmptyString([
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
    final bool userActive = userData['is_active'] == true;
    final bool profileActive = profileData?['is_active'] == true;

    final String userStatus = _readString(userData['status']).toLowerCase();
    final String profileStatus =
        _readString(profileData?['status']).toLowerCase();

    if (userActive || profileActive) {
      return true;
    }

    if (userStatus == 'approved' || profileStatus == 'approved') {
      return true;
    }

    return false;
  }

  bool _looksActive({
    required Map<String, dynamic> userData,
    Map<String, dynamic>? profileData,
  }) {
    final bool userActive = userData['is_active'] == true;
    final bool profileActive = profileData?['is_active'] == true;

    final String userStatus = _readString(userData['status']).toLowerCase();
    final String profileStatus =
        _readString(profileData?['status']).toLowerCase();

    if (userActive || profileActive) {
      return true;
    }

    return userStatus == 'approved' || profileStatus == 'approved';
  }

  String _firstNonEmptyString(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = _readString(value);
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  int _sortEventsForAdmin(EventModel a, EventModel b) {
    final Map<String, int> order = <String, int>{
      EventModel.statusPublished: 0,
      EventModel.statusDraft: 1,
      EventModel.statusClosed: 2,
      EventModel.statusCancelled: 3,
    };

    final int left = order[a.status] ?? 99;
    final int right = order[b.status] ?? 99;

    if (left != right) {
      return left.compareTo(right);
    }

    final DateTime aTime = a.startDateTime ??
        a.eventDateTime ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime bTime = b.startDateTime ??
        b.eventDateTime ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return bTime.compareTo(aTime);
  }

  int _sortEventsForEmployee(EventModel a, EventModel b) {
    final int priorityA = a.isPublished ? 0 : 1;
    final int priorityB = b.isPublished ? 0 : 1;

    if (priorityA != priorityB) {
      return priorityA.compareTo(priorityB);
    }

    final DateTime aTime = a.startDateTime ??
        a.eventDateTime ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime bTime = b.startDateTime ??
        b.eventDateTime ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return aTime.compareTo(bTime);
  }

  void _validateEventDocumentId(String eventId) {
    if (eventId.trim().isEmpty) {
      throw Exception('Event ID cannot be empty.');
    }
  }

  String _readString(dynamic value, {String fallback = ''}) {
    final String text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
    return fallback.trim();
  }

  String _formatDateTime(DateTime value) {
    final DateTime local = value.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String year = local.year.toString();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute';
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

class _SummaryComputation {
  const _SummaryComputation({
    required this.summary,
  });

  final EventAttendanceSummaryModel summary;
}
