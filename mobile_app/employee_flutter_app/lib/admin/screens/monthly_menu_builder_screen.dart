import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MonthlyMenuBuilderScreen extends StatefulWidget {
  final String userEmail; // Accepting userEmail as a required parameter

  // Constructor now expects userEmail
  const MonthlyMenuBuilderScreen({super.key, required this.userEmail});

  @override
  _MonthlyMenuBuilderScreenState createState() =>
      _MonthlyMenuBuilderScreenState();
}

class _MonthlyMenuBuilderScreenState extends State<MonthlyMenuBuilderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // This function will be used to save the menu data to Firestore
  void _saveMonthlyMenu() async {
    // Sample data for the menu (replace with actual data collection)
    List<String> breakfastItems = ["item1", "item2"]; // Replace with actual data
    List<String> lunchItems = ["item3", "item4"]; // Replace with actual data
    List<String> dinnerItems = ["item5", "item6"]; // Replace with actual data

    try {
      // Save the menu to `menu_cycles` collection instead of `daily_menus`
      await _firestore.collection('menu_cycles').add({
        'month': DateTime.now().month,
        'year': DateTime.now().year,
        'cycle_items': {
          'breakfast': breakfastItems,
          'lunch': lunchItems,
          'dinner': dinnerItems,
        },
        'created_by': widget.userEmail, // Store userEmail to track the creator
        'created_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Monthly menu saved successfully'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error saving menu: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Monthly Menu Builder"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _saveMonthlyMenu,
          child: Text("Save Menu"),
        ),
      ),
    );
  }
}
