import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MealFeedbackDashboardScreen extends StatelessWidget {
  const MealFeedbackDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Feedback Analytics"),
          bottom: const TabBar(tabs: [Tab(text: "Breakfast"), Tab(text: "Lunch"), Tab(text: "Dinner")]),
        ),
        body: TabBarView(children: [_buildList("breakfast"), _buildList("lunch"), _buildList("dinner")]),
      ),
    );
  }

  Widget _buildList(String mealType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('meal_feedback').where('meal_type', isEqualTo: mealType).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs; // FIX: Correct data access
        if (docs.isEmpty) return const Center(child: Text("No feedback."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return ListTile(title: Text(data['comment'] ?? "No Comment"), subtitle: Text("Rating: ${data['rating']}"));
          },
        );
      },
    );
  }
}
