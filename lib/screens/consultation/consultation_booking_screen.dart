import 'package:flutter/material.dart';
import 'package:connect_app/services/consultation_service.dart';
import 'package:intl/intl.dart';

class ConsultationBookingScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final int? ratePerMinute;

  const ConsultationBookingScreen({
    Key? key,
    required this.targetUserId,
    required this.targetUserName,
    this.ratePerMinute,
  }) : super(key: key);

  @override
  State<ConsultationBookingScreen> createState() => _ConsultationBookingScreenState();
}

class _ConsultationBookingScreenState extends State<ConsultationBookingScreen> {
  final ConsultationService _consultationService = ConsultationService();

  // Selected duration in minutes
  int _selectedDuration = 15;
  bool _isProcessing = false;
  final List<int> _durationOptions = [15, 30, 45, 60];

  // For scheduling
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Pick a date
  Future<void> _pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  // Pick a time
  Future<void> _pickTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  // Combine date + time into a single DateTime
  DateTime? getScheduledDateTime() {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  Future<void> _bookConsultation() async {
    setState(() => _isProcessing = true);

    try {
      // If user didn't pick a date/time, default to "now"
      final DateTime scheduledAt = getScheduledDateTime() ?? DateTime.now();

      // Book the consultation, passing scheduledAt
      await _consultationService.bookConsultation(
        widget.targetUserId,
        _selectedDuration,
        scheduledAt: scheduledAt,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation booked successfully.')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking consultation: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduledDateTime = getScheduledDateTime();
    final scheduledDateString = (scheduledDateTime == null)
        ? 'Not set'
        : DateFormat('MMM d, yyyy - hh:mm a').format(scheduledDateTime);

    return Scaffold(
      appBar: AppBar(
        title: Text('Book Consultation with ${widget.targetUserName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isProcessing
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consultation Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Expert: ${widget.targetUserName}'),
                  if (widget.ratePerMinute != null)
                    Text('Rate: \$${widget.ratePerMinute} per minute'),
                  const SizedBox(height: 16),
                  Text(
                    'Select Duration (minutes):',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  DropdownButton<int>(
                    value: _selectedDuration,
                    items: _durationOptions.map((duration) {
                      return DropdownMenuItem<int>(
                        value: duration,
                        child: Text('$duration minutes'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDuration = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _pickDate,
                        child: Text(
                          _selectedDate == null
                              ? 'Pick Date'
                              : DateFormat('MMM d, yyyy').format(_selectedDate!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _pickTime,
                        child: Text(
                          _selectedTime == null
                              ? 'Pick Time'
                              : _selectedTime!.format(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Scheduled At: $scheduledDateString'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _bookConsultation,
                    child: const Text('Book Consultation'),
                  ),
                ],
              ),
      ),
    );
  }
}
