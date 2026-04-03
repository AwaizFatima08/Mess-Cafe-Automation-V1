import 'package:flutter/material.dart';
import '../../services/meal_reservation_service.dart';

class GuestMealBookingScreen extends StatefulWidget {
  const GuestMealBookingScreen({super.key});

  @override
  State<GuestMealBookingScreen> createState() => _GuestMealBookingScreenState();
}

class _GuestMealBookingScreenState extends State<GuestMealBookingScreen> {
  final MealReservationService _reservationService = MealReservationService();
  
  String _selectedMealType = 'lunch';
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _countController = TextEditingController(text: "1");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Guest & Proxy Booking")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFormCard(),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _handleGuestBooking,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: const Text("Confirm Guest Booking"),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedMealType,
              items: ['breakfast', 'lunch', 'dinner'].map((m) => DropdownMenuItem(value: m, child: Text(m.toUpperCase()))).toList(),
              onChanged: (val) => setState(() => _selectedMealType = val!),
              decoration: const InputDecoration(labelText: "Meal Type"),
            ),
            TextField(
              controller: _guestNameController,
              decoration: const InputDecoration(labelText: "Guest Name / Reference"),
            ),
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Number of Guests"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGuestBooking() async {
    final count = int.tryParse(_countController.text) ?? 1;
    
    // PHASE 11 FIX: Using the restored constants and new save method
    final guestData = {
      'employee_number': 'GUEST_${DateTime.now().millisecondsSinceEpoch}',
      'full_name': _guestNameController.text,
      'meal_type': _selectedMealType,
      'reservation_date': _selectedDate,
      'category': MealReservationService.categoryOfficialGuest,
      'booking_source': MealReservationService.bookingSourceAdminConsole,
      'quantity': count,
    };

    try {
      await _reservationService.saveReservation(guestData);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Handle error
    }
  }
}
