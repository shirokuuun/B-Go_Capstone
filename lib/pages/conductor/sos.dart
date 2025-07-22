import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SOSPage extends StatefulWidget {
  final String route;
  final String placeCollection;

  SOSPage({Key? key, required this.route, required this.placeCollection}) : super(key: key);

  @override
  State<SOSPage> createState() => _SOSPageState();
}

class _SOSPageState extends State<SOSPage> {
  final routeService = RouteService();
  final TextEditingController _descriptionController = TextEditingController();

  String? selectedEmergencyType;
  Map<String, dynamic>? latestSOS;
  bool isLoading = true;

  List<String> emergencyTypes = [
    'Mechanical Failure',
    'Flat Tire',
    'Brake Failure',
    'Accident',
    'Medical Emergency',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    loadLatestSOS();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadLatestSOS() async {
    setState(() => isLoading = true);
    final sosData = await routeService.fetchLatestSOS(getRouteLabel(widget.placeCollection));
    setState(() {
      latestSOS = sosData;
      isLoading = false;
    });
  }

  String getRouteLabel(String placeCollection) {
    final route = widget.route.trim();
    final map = {
      'Rosario': {'Place': 'SM City Lipa - Rosario', 'Place 2': 'Rosario - SM City Lipa'},
      'Batangas': {'Place': 'SM City Lipa - Batangas City', 'Place 2': 'Batangas City - SM City Lipa'},
      'Mataas na Kahoy': {'Place': 'SM City Lipa - Mataas na Kahoy', 'Place 2': 'Mataas na Kahoy - SM City Lipa'},
      'Tiaong': {'Place': 'SM City Lipa - Tiaong', 'Place 2': 'Tiaong - SM City Lipa'},
    };
    return map[route]?[placeCollection] ?? 'Unknown Route';
  }

  Color getStatusColor(String? status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Received':
        return Colors.blue;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.transparent;
    }
  }

  void resetFields() {
    setState(() {
      selectedEmergencyType = null;
      _descriptionController.clear();
      latestSOS = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) resetFields();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('SOS - Emergency Assistance',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
          backgroundColor: const Color(0xFF1D2B53),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: loadLatestSOS,
              tooltip: 'Refresh SOS',
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SOS Button
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      if (latestSOS != null &&
                          (latestSOS!['status'] == 'Pending' || latestSOS!['status'] == 'In Progress')) {
                        await showDialog(
                          context: context,
                          builder: (_) => const AlertDialog(
                            title: Text('SOS Received'),
                            content: Text('The SOS has already been marked.'),
                          ),
                        );
                        return;
                      }

                      if (selectedEmergencyType == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select an emergency type.')),
                        );
                        return;
                      }

                      if (selectedEmergencyType == 'Other' && _descriptionController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please provide details for "Other".')),
                        );
                        return;
                      }

                      try {
                        await routeService.sendSOS(
                          emergencyType: selectedEmergencyType!,
                          description: _descriptionController.text,
                          lat: 0.0,
                          lng: 0.0,
                          route: getRouteLabel(widget.placeCollection),
                          isActive: true,
                        );
                        await loadLatestSOS();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('SOS request sent successfully!')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error sending SOS: $e')),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Column(
                        children: [
                          Icon(Icons.sos, size: MediaQuery.of(context).size.width * 0.2, color: Colors.white),
                          const SizedBox(height: 8),
                          Text('Tap to send SOS',
                              style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * 0.035,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Dropdown
                Row(children: [
                  const Icon(Icons.warning, color: Colors.red, size: 30),
                  const SizedBox(width: 10),
                  Text('Select Emergency Type', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: emergencyTypes.contains(selectedEmergencyType) ? selectedEmergencyType : null,
                  decoration: InputDecoration(
                    hintText: "Choose an emergency type",
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (value) => setState(() => selectedEmergencyType = value),
                  items: emergencyTypes
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                ),

                const SizedBox(height: 20),

                // Description
                Row(children: [
                  const Icon(Icons.edit, color: Colors.red, size: 30),
                  const SizedBox(width: 10),
                  Text('Enter Emergency Details',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Enter emergency details',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 20),

                // Location (static placeholder)
                Row(children: [
                  const Icon(Icons.location_on, color: Colors.black, size: 30),
                  const SizedBox(width: 10),
                  Text('Current Location',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                const Text('GPS'), // Placeholder

                const SizedBox(height: 20),

                // Status
                Row(children: [
                  const Icon(Icons.hourglass_empty, color: Colors.black, size: 30),
                  const SizedBox(width: 10),
                  Text('Status:', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  if (!isLoading && latestSOS != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: getStatusColor(latestSOS?['status']),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(latestSOS!['status'],
                          style: GoogleFonts.outfit(fontSize: 16, color: Colors.white)),
                    ),
                ]),

                if (latestSOS != null) ...[
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('🚨 SOS Details'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Emergency Type: ${latestSOS!['emergencyType']}'),
                            Text('Description: ${latestSOS!['description']}'),
                            Text('Status: ${latestSOS!['status']}'),
                            Text('Time: ${latestSOS!['timestamp'] != null ? (latestSOS!['timestamp'] as Timestamp).toDate().toLocal().toString() : 'Unknown'}',),
                            Text('Route: ${latestSOS!['route']}'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                          TextButton(
                            onPressed: () async {
                              try {
                                await RouteService().cancelSOS(latestSOS!['id']);
                                if (mounted) {
                                  Navigator.of(context).pop(); // close dialog
                                  await showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: Row(
                                      children: [
                                        Icon(Icons.cancel, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('SOS Cancelled'),
                                      ],
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'The SOS has been cancelled.',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                        SizedBox(height: 16),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: Text(
                                          'OK',
                                          style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                                  resetFields();
                                  await loadLatestSOS();
                                }
                              } catch (e) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to cancel SOS: $e')),
                                );
                              }
                            },
                            child: const Text('Cancel SOS', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                    child: Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            Text('Tap to view SOS details',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                if (latestSOS != null && latestSOS!['status'] == 'Pending')
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: ElevatedButton.icon(
                      onPressed: () async { //pansamantala, habang wala pang admin dashnoard
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Confirm'),
                            content: const Text('Are you sure you want to mark this SOS as received?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm')),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          try {
                            await routeService.updateSOSStatusByRoute(getRouteLabel(widget.placeCollection), false);
                            await showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('SOS Received'),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'The SOS has been successfully marked as received.',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  SizedBox(height: 16),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(
                                    'OK',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                            resetFields();
                            await loadLatestSOS();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update SOS: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark as Received'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
