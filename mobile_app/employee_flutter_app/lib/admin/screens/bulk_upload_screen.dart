import 'package:flutter/material.dart';
import '../widgets/admin_section_placeholder_card.dart';

class BulkUploadScreen extends StatelessWidget {
  final String userEmail;

  const BulkUploadScreen({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return AdminSectionPlaceholderCard(
      title: 'Bulk Upload',
      subtitle: 'Upload menu items and master data in bulk',
      icon: Icons.upload_file_outlined,
      userEmail: userEmail,
    );
  }
}
