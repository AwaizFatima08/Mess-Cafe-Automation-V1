import 'package:cloud_firestore/cloud_firestore.dart';

class EventNoteTemplateModel {
  static const String collectionName = 'event_note_templates';

  final String documentId;
  final String templateId;
  final String title;
  final String body;
  final bool isActive;
  final bool isVisible;
  final int displayOrder;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Map<String, dynamic> rawData;

  const EventNoteTemplateModel({
    required this.documentId,
    required this.templateId,
    required this.title,
    required this.body,
    required this.isActive,
    required this.isVisible,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.rawData,
  });

  factory EventNoteTemplateModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return EventNoteTemplateModel.fromMap(
      data,
      documentId: document.id,
    );
  }

  factory EventNoteTemplateModel.fromMap(
    Map<String, dynamic> map, {
    required String documentId,
  }) {
    final String cleanDocumentId = documentId.trim();
    final String cleanTemplateId = _readString(
      map['template_id'],
      fallback: cleanDocumentId,
    );

    return EventNoteTemplateModel(
      documentId: cleanDocumentId,
      templateId: cleanTemplateId,
      title: _readString(map['title']),
      body: _readString(map['body']),
      isActive: _readBool(map['is_active'], fallback: true),
      isVisible: _readBool(map['is_visible'], fallback: true),
      displayOrder: _readInt(map['display_order'], fallback: 0),
      createdAt: _readTimestamp(map['created_at']),
      updatedAt: _readTimestamp(map['updated_at']),
      rawData: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap({
    bool includeNulls = false,
  }) {
    final map = <String, dynamic>{
      'template_id': templateId.trim().isEmpty ? documentId.trim() : templateId.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'is_active': isActive,
      'is_visible': isVisible,
      'display_order': displayOrder,
    };

    _writeTimestamp(
      map,
      'created_at',
      createdAt,
      includeNulls: includeNulls,
    );
    _writeTimestamp(
      map,
      'updated_at',
      updatedAt,
      includeNulls: includeNulls,
    );

    return map;
  }

  EventNoteTemplateModel copyWith({
    String? documentId,
    String? templateId,
    String? title,
    String? body,
    bool? isActive,
    bool? isVisible,
    int? displayOrder,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Map<String, dynamic>? rawData,
  }) {
    return EventNoteTemplateModel(
      documentId: documentId ?? this.documentId,
      templateId: templateId ?? this.templateId,
      title: title ?? this.title,
      body: body ?? this.body,
      isActive: isActive ?? this.isActive,
      isVisible: isVisible ?? this.isVisible,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rawData: rawData ?? this.rawData,
    );
  }

  bool get isValid => title.trim().isNotEmpty && body.trim().isNotEmpty;

  @override
  String toString() {
    return 'EventNoteTemplateModel(documentId: $documentId, title: $title)';
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final text = (value?.toString() ?? '').trim();
    return text.isEmpty ? fallback.trim() : text;
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value == null) {
      return fallback;
    }
    return int.tryParse(value.toString().trim()) ?? fallback;
  }

  static bool _readBool(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    if (value == null) {
      return fallback;
    }

    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }

    return fallback;
  }

  static Timestamp? _readTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value;
    }
    return null;
  }

  static void _writeTimestamp(
    Map<String, dynamic> target,
    String key,
    Timestamp? value, {
    required bool includeNulls,
  }) {
    if (value != null || includeNulls) {
      target[key] = value;
    }
  }
}
