import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:b_go/pages/conductor/conductor_home.dart';
import 'package:b_go/pages/conductor/ticketing/conductor_from.dart';
import 'package:b_go/pages/conductor/remittance_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ConductorDeparture extends StatefulWidget {
  final String route;
  final String role;

  const ConductorDeparture({
    Key? key,
    required this.route,
    required this.role,
  }) : super(key: key);

  @override
  State<ConductorDeparture> createState() => _ConductorDepartureState();
}

class _ConductorDepartureState extends State<ConductorDeparture> {
  String selectedPlaceCollection = 'Place';
  late List<Map<String, String>> routeDirections;
  bool isTripActive = false;
  String? currentTripDirection;
  DateTime? tripStartTime;
  String? currentTripId;

  @override
  void initState() {
    super.initState();
    _initializeRouteDirections();
    _checkActiveTrip();
  }

  void _initializeRouteDirections() {
    if ('${widget.route.trim()}' == 'Rosario') {
      routeDirections = [
        {'label': 'SM City Lipa - Rosario', 'collection': 'Place'},
        {'label': 'Rosario - SM City Lipa', 'collection': 'Place 2'},
      ];
    } else if ('${widget.route.trim()}' == 'Batangas') {
      routeDirections = [
        {'label': 'SM City Lipa - Batangas City', 'collection': 'Place'},
        {'label': 'Batangas City - SM City Lipa', 'collection': 'Place 2'},
      ];
    } else if ('${widget.route}' == 'Mataas na Kahoy') {
      routeDirections = [
        {'label': 'SM City Lipa - Mataas na Kahoy', 'collection': 'Place'},
        {'label': 'Mataas na Kahoy - SM City Lipa', 'collection': 'Place 2'},
      ];
    } else if ('${widget.route.trim()}' == 'Mataas Na Kahoy Palengke') {
      routeDirections = [
        {'label': 'Lipa Palengke - Mataas na Kahoy', 'collection': 'Place'},
        {'label': 'Mataas na Kahoy - Lipa Palengke', 'collection': 'Place 2'},
      ];
    } else if ('${widget.route.trim()}' == 'Tiaong') {
      routeDirections = [
        {'label': 'SM City Lipa - Tiaong', 'collection': 'Place'},
        {'label': 'Tiaong - SM City Lipa', 'collection': 'Place 2'},
      ];
    } else if ('${widget.route.trim()}' == 'San Juan') {
      routeDirections = [
        {'label': 'SM City Lipa - San Juan', 'collection': 'Place'},
        {'label': 'San Juan - SM City Lipa', 'collection': 'Place 2'},
      ];
    } else {
      routeDirections = [
        {'label': 'SM City Lipa - Unknown', 'collection': 'Place'},
        {'label': 'Unknown - SM City Lipa', 'collection': 'Place 2'},
      ];
    }
  }

  Future<void> _checkActiveTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorDoc.docs.isNotEmpty) {
        final conductorData = conductorDoc.docs.first.data();
        final activeTrip = conductorData['activeTrip'];
        
        if (activeTrip != null && activeTrip['isActive'] == true) {
          setState(() {
            isTripActive = true;
            currentTripDirection = activeTrip['direction'];
            selectedPlaceCollection = activeTrip['placeCollection'];
            tripStartTime = (activeTrip['startTime'] as Timestamp).toDate();
            currentTripId = activeTrip['tripId'];
          });
        }
      }
    } catch (e) {
      print('Error checking active trip: $e');
    }
  }

  Future<void> _startNewTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorDoc.docs.isNotEmpty) {
        final conductorDocId = conductorDoc.docs.first.id;
        
        // Check if location tracking is active
        final conductorData = conductorDoc.docs.first.data();
        final isLocationTrackingActive = conductorData['isOnline'] ?? false;
        
        if (!isLocationTrackingActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location tracking must be active before starting a trip. Please enable location tracking in the Dashboard first.',
                style: GoogleFonts.outfit(fontSize: 14),
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Go to Dashboard',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ConductorHome(
                        route: widget.route,
                        role: widget.role,
                        placeCollection: selectedPlaceCollection,
                        selectedIndex: 0, // Dashboard tab
                      ),
                    ),
                  );
                },
              ),
            ),
          );
          return;
        }
        
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        // Check if there's an incomplete round trip for today
        try {
          final dailyTripDoc = await FirebaseFirestore.instance
              .collection('conductors')
              .doc(conductorDocId)
              .collection('dailyTrips')
              .doc(today)
              .get();
          
          if (dailyTripDoc.exists) {
            final dailyTripData = dailyTripDoc.data();
            final isRoundTripComplete = dailyTripData?['isRoundTripComplete'] ?? false;
            
            if (!isRoundTripComplete) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('You have an incomplete round trip. Please complete the current round trip first.'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
          }
        } catch (e) {
          print('Error checking daily trip status: $e');
          // Continue with trip creation even if there's a permission error
        }
        
        final now = DateTime.now();
        final tripId = 'trip_${now.millisecondsSinceEpoch}';
        
                 // Create or update daily trip document
         try {
           final dailyTripDoc = await FirebaseFirestore.instance
               .collection('conductors')
               .doc(conductorDocId)
               .collection('dailyTrips')
               .doc(today)
               .get();
           
           if (!dailyTripDoc.exists) {
             // This is the first trip of the day - create trip1
             await FirebaseFirestore.instance
                 .collection('conductors')
                 .doc(conductorDocId)
                 .collection('dailyTrips')
                 .doc(today)
                 .set({
                   'date': today,
                   'trip1': {
                     'startTime': Timestamp.fromDate(now),
                     'direction': routeDirections.firstWhere((r) => r['collection'] == selectedPlaceCollection)['label'],
                     'placeCollection': selectedPlaceCollection,
                     'isComplete': false,
                   },
                   'currentTrip': 1,
                   'isRoundTripComplete': false,
                   'createdAt': FieldValue.serverTimestamp(),
                 });
           } else {
             // Check if we need to start trip2 (vice versa)
             final dailyTripData = dailyTripDoc.data();
             final currentTrip = dailyTripData?['currentTrip'] ?? 1;
             
             if (currentTrip % 2 == 1 && dailyTripData?['trip$currentTrip']?['isComplete'] == true) {
               // Odd-numbered trip is complete, start the next even trip with opposite direction
               final currentTripPlaceCollection = dailyTripData?['trip$currentTrip']?['placeCollection'] ?? 'Place';
               final oppositePlaceCollection = currentTripPlaceCollection == 'Place' ? 'Place 2' : 'Place';
               final oppositeDirection = routeDirections.firstWhere((r) => r['collection'] == oppositePlaceCollection)['label'];
               
               await FirebaseFirestore.instance
                   .collection('conductors')
                   .doc(conductorDocId)
                   .collection('dailyTrips')
                   .doc(today)
                   .update({
                     'trip${currentTrip + 1}': {
                       'startTime': Timestamp.fromDate(now),
                       'direction': oppositeDirection,
                       'placeCollection': oppositePlaceCollection,
                       'isComplete': false,
                     },
                     'currentTrip': currentTrip + 1,
                     'isRoundTripComplete': false,
                   });
               
               // Update selected place collection for the UI to show the opposite direction
               setState(() {
                 selectedPlaceCollection = oppositePlaceCollection;
               });
             } else if (dailyTripData?['trip$currentTrip']?['isComplete'] == false) {
               // Current trip is in progress, continue with it
               final currentTripPlaceCollection = dailyTripData?['trip$currentTrip']?['placeCollection'] ?? 'Place';
               final currentTripDirection = dailyTripData?['trip$currentTrip']?['direction'] ?? 'Place to Place 2';
               
               setState(() {
                 selectedPlaceCollection = currentTripPlaceCollection;
               });
               
               // No need to update dailyTrips document since the current trip is already set up
             } else if (dailyTripData?['isRoundTripComplete'] == true) {
               // Start a new round trip with conductor's chosen direction
               // Find the next available trip number
               int nextTripNumber = 1;
               while (dailyTripData?['trip$nextTripNumber'] != null) {
                 nextTripNumber++;
               }
               
               await FirebaseFirestore.instance
                   .collection('conductors')
                   .doc(conductorDocId)
                   .collection('dailyTrips')
                   .doc(today)
                   .update({
                     'trip$nextTripNumber': {
                       'startTime': Timestamp.fromDate(now),
                       'direction': routeDirections.firstWhere((r) => r['collection'] == selectedPlaceCollection)['label'],
                       'placeCollection': selectedPlaceCollection,
                       'isComplete': false,
                     },
                     'currentTrip': nextTripNumber,
                     'isRoundTripComplete': false,
                   });
             } else {
               // Continue with current trip direction (for ongoing trips)
               await FirebaseFirestore.instance
                   .collection('conductors')
                   .doc(conductorDocId)
                   .collection('dailyTrips')
                   .doc(today)
                   .update({
                     'trip1': {
                       'startTime': Timestamp.fromDate(now),
                       'direction': routeDirections.firstWhere((r) => r['collection'] == selectedPlaceCollection)['label'],
                       'placeCollection': selectedPlaceCollection,
                       'isComplete': false,
                     },
                     'currentTrip': 1,
                     'isRoundTripComplete': false,
                   });
             }
           }
         } catch (e) {
           print('Error creating/updating daily trip document: $e');
         }
        
        // Get current trip number for the activeTrip field
        final dailyTripDoc = await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorDocId)
            .collection('dailyTrips')
            .doc(today)
            .get();
        
        final currentTripNumber = dailyTripDoc.exists ? (dailyTripDoc.data()?['currentTrip'] ?? 1) : 1;
        
        // Update conductor document with active trip
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorDocId)
            .update({
              'activeTrip': {
                'isActive': true,
                'direction': routeDirections.firstWhere((r) => r['collection'] == selectedPlaceCollection)['label'],
                'placeCollection': selectedPlaceCollection,
                'startTime': Timestamp.fromDate(now),
                'tripId': tripId,
                'isReturnTrip': currentTripNumber == 2, // Mark as return trip if this is trip2
              },
              'passengerCount': 0, // Reset passenger count for new trip
            });

        setState(() {
          isTripActive = true;
          currentTripDirection = routeDirections.firstWhere((r) => r['collection'] == selectedPlaceCollection)['label'];
          tripStartTime = now;
          currentTripId = tripId;
        });

        // Navigate to ticketing page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ConductorFrom(
              route: widget.route,
              role: widget.role,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting trip: $e')),
      );
    }
  }

  Future<void> _endCurrentTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorDoc.docs.isNotEmpty) {
        final conductorDocId = conductorDoc.docs.first.id;
        final conductorData = conductorDoc.docs.first.data();
        final activeTrip = conductorData['activeTrip'];
        
        if (activeTrip != null) {
          final currentDirection = activeTrip['direction'];
          final currentPlaceCollection = activeTrip['placeCollection'];
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          
          // Move tickets from 'trips' to 'remittance' collection
          try {
            final ticketsSnapshot = await FirebaseFirestore.instance
                .collection('conductors')
                .doc(conductorDocId)
                .collection('trips')
                .doc(today)
                .collection('tickets')
                .get();
            
            // Create remittance collection and move all tickets
            for (var ticket in ticketsSnapshot.docs) {
              final ticketData = ticket.data();
              await FirebaseFirestore.instance
                  .collection('conductors')
                  .doc(conductorDocId)
                  .collection('remittance')
                  .doc(today)
                  .collection('tickets')
                  .doc(ticket.id)
                  .set(ticketData);
            }
            
            // Delete the old trips collection
            await FirebaseFirestore.instance
                .collection('conductors')
                .doc(conductorDocId)
                .collection('trips')
                .doc(today)
                .delete();
                
            // Calculate and save remittance summary
            try {
              final remittanceSummary = await RemittanceService.calculateDailyRemittance(conductorDocId, today);
              await RemittanceService.saveRemittanceSummary(conductorDocId, today, remittanceSummary);
              print('✅ Remittance summary calculated and saved for $today');
            } catch (e) {
              print('Error calculating remittance summary: $e');
            }
          } catch (e) {
            print('Error moving tickets to remittance: $e');
          }
          
          // Check if this is trip1 or trip2 and handle accordingly
          try {
            final dailyTripDoc = await FirebaseFirestore.instance
                .collection('conductors')
                .doc(conductorDocId)
                .collection('dailyTrips')
                .doc(today)
                .get();
            
            if (dailyTripDoc.exists) {
              final dailyTripData = dailyTripDoc.data();
              final currentTrip = dailyTripData?['currentTrip'] ?? 1;
              
              if (currentTrip % 2 == 1) {
                // This was an odd-numbered trip (trip1, trip3, trip5, etc.), mark it as complete and start the next even trip
                await FirebaseFirestore.instance
                    .collection('conductors')
                    .doc(conductorDocId)
                    .collection('dailyTrips')
                    .doc(today)
                    .update({
                      'trip$currentTrip.isComplete': true,
                      'trip$currentTrip.endTime': FieldValue.serverTimestamp(),
                      'currentTrip': currentTrip + 1, // Increment to next trip
                    });
                
                // Start next trip with opposite direction
                final oppositePlaceCollection = currentPlaceCollection == 'Place' ? 'Place 2' : 'Place';
                final oppositeDirection = routeDirections.firstWhere((r) => r['collection'] == oppositePlaceCollection)['label'];
                final nextTripId = 'trip_${DateTime.now().millisecondsSinceEpoch}';
                
                // Create next trip document in dailyTrips
                await FirebaseFirestore.instance
                    .collection('conductors')
                    .doc(conductorDocId)
                    .collection('dailyTrips')
                    .doc(today)
                    .update({
                      'trip${currentTrip + 1}': {
                        'startTime': Timestamp.fromDate(DateTime.now()),
                        'direction': oppositeDirection,
                        'placeCollection': oppositePlaceCollection,
                        'isComplete': false,
                        'tripId': nextTripId,
                      },
                    });
                
                await FirebaseFirestore.instance
                    .collection('conductors')
                    .doc(conductorDocId)
                    .update({
                      'activeTrip': {
                        'isActive': true,
                        'direction': oppositeDirection,
                        'placeCollection': oppositePlaceCollection,
                        'startTime': Timestamp.fromDate(DateTime.now()),
                        'tripId': nextTripId,
                        'isReturnTrip': true,
                      },
                      'passengerCount': 0, // Reset for return trip
                    });
                
                setState(() {
                  isTripActive = true;
                  selectedPlaceCollection = oppositePlaceCollection;
                  currentTripDirection = oppositeDirection;
                  tripStartTime = DateTime.now();
                  currentTripId = nextTripId;
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Trip $currentTrip completed. Starting Trip ${currentTrip + 1} (return direction).')),
                );
              } else if (currentTrip % 2 == 0) {
                // This was an even-numbered trip (trip2, trip4, trip6, etc.), complete the round trip and allow new trip selection
                await FirebaseFirestore.instance
                    .collection('conductors')
                    .doc(conductorDocId)
                    .collection('dailyTrips')
                    .doc(today)
                    .update({
                      'trip$currentTrip.isComplete': true,
                      'trip$currentTrip.endTime': FieldValue.serverTimestamp(),
                      'isRoundTripComplete': true,
                      'endTime': FieldValue.serverTimestamp(),
                    });
                
                // Clear active trip and reset to allow new trip selection
                await FirebaseFirestore.instance
                    .collection('conductors')
                    .doc(conductorDocId)
                    .update({
                      'activeTrip': FieldValue.delete(),
                      'passengerCount': 0,
                    });
                
                setState(() {
                  isTripActive = false;
                  currentTripDirection = null;
                  tripStartTime = null;
                  currentTripId = null;
                  selectedPlaceCollection = 'Place'; // Reset to first direction
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Round trip completed successfully! You can now start a new trip.')),
                );
              }
            } else {
              // No daily trip document exists, just complete the current trip
              await FirebaseFirestore.instance
                  .collection('conductors')
                  .doc(conductorDocId)
                  .update({
                    'activeTrip': FieldValue.delete(),
                    'passengerCount': 0,
                  });
              
              setState(() {
                isTripActive = false;
                currentTripDirection = null;
                tripStartTime = null;
                currentTripId = null;
                selectedPlaceCollection = 'Place';
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Trip completed successfully!')),
              );
            }
          } catch (e) {
            print('Error checking trip direction: $e');
            // Default to completing the trip
            await FirebaseFirestore.instance
                .collection('conductors')
                .doc(conductorDocId)
                .update({
                  'activeTrip': FieldValue.delete(),
                  'passengerCount': 0,
                });
            
            setState(() {
              isTripActive = false;
              currentTripDirection = null;
              tripStartTime = null;
              currentTripId = null;
              selectedPlaceCollection = 'Place';
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Trip completed successfully!')),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ending trip: $e')),
      );
    }
  }

  Future<void> _continueCurrentTrip() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ConductorFrom(
          route: widget.route,
          role: widget.role,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF0091AD),
            expandedHeight: 80,
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                children: [
                  // App bar content
                  Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => ConductorHome(
                                    route: widget.route,
                                    role: widget.role,
                                    placeCollection: selectedPlaceCollection,
                                    selectedIndex: 0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Trip Departure',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trip Status Section
                  if (isTripActive) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF4CAF50)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.directions_bus, color: Color(0xFF4CAF50)),
                              SizedBox(width: 8),
                              Text(
                                'Active Trip',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                              if (currentTripId != null && currentTripId!.contains('return'))
                                Container(
                                  margin: EdgeInsets.only(left: 8),
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Return Trip',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Direction: $currentTripDirection',
                            style: GoogleFonts.outfit(fontSize: 16),
                          ),
                          if (tripStartTime != null)
                            Text(
                              'Started: ${DateFormat('MMM dd, yyyy - HH:mm').format(tripStartTime!)}',
                              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                                     // Trip Direction Selection
                   Text(
                     isTripActive ? 'Current Trip Direction:' : 'Select Trip Direction:',
                     style: GoogleFonts.outfit(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                       color: Colors.black87,
                     ),
                   ),
                   if (!isTripActive) ...[
                     SizedBox(height: 8),
                     Container(
                       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                       decoration: BoxDecoration(
                         color: Colors.blue[50],
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.blue[200]!),
                       ),
                       child: Text(
                         'Complete both directions to finish round trip',
                         style: GoogleFonts.outfit(
                           fontSize: 12,
                           color: Colors.blue[700],
                         ),
                       ),
                     ),
                   ],
                   if (isTripActive) ...[
                     SizedBox(height: 8),
                     Container(
                       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                       decoration: BoxDecoration(
                         color: Colors.orange[50],
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.orange[200]!),
                       ),
                       child: Text(
                         'Direction cannot be changed during active trip',
                         style: GoogleFonts.outfit(
                           fontSize: 12,
                           color: Colors.orange[700],
                         ),
                       ),
                     ),
                   ],
                  SizedBox(height: 16),

                                     // Direction Selection Cards
                   ...routeDirections.map((direction) {
                     final isSelected = direction['collection'] == selectedPlaceCollection;
                     final isDisabled = isTripActive && !isSelected;
                     
                     return Container(
                       margin: EdgeInsets.only(bottom: 12),
                       child: GestureDetector(
                         onTap: isDisabled ? null : () {
                           if (!isTripActive) {
                             setState(() {
                               selectedPlaceCollection = direction['collection']!;
                             });
                           }
                         },
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                           decoration: BoxDecoration(
                             color: isSelected 
                                 ? const Color(0xFF0091AD) 
                                 : isDisabled 
                                     ? Colors.grey[300]
                                     : const Color(0xFF007A8F),
                             borderRadius: BorderRadius.circular(16),
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withOpacity(0.3),
                                 blurRadius: 6,
                                 offset: const Offset(0, 3),
                               ),
                             ],
                           ),
                           child: Row(
                             children: [
                               Icon(
                                 Icons.swap_horiz, 
                                 color: isDisabled ? Colors.grey[600] : Colors.white
                               ),
                               SizedBox(width: 12),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(
                                       direction['label']!,
                                       style: GoogleFonts.outfit(
                                         fontSize: 18,
                                         color: isDisabled ? Colors.grey[600] : Colors.white,
                                         fontWeight: FontWeight.w600,
                                       ),
                                     ),
                                     if (isSelected && isTripActive)
                                       Text(
                                         'Current Trip',
                                         style: GoogleFonts.outfit(
                                           fontSize: 12,
                                           color: Colors.white70,
                                         ),
                                       ),
                                   ],
                                 ),
                               ),
                               if (isSelected && !isDisabled)
                                 Icon(Icons.check_circle, color: Colors.white),
                             ],
                           ),
                         ),
                       ),
                     );
                   }).toList(),

                  SizedBox(height: 24),

                  // Current Time Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: Color(0xFF0091AD)),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Time',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              DateFormat('MMM dd, yyyy - HH:mm:ss').format(DateTime.now()),
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0091AD),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  // Location Tracking Requirement Notice
                  if (!isTripActive) ...[
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Before Starting Your Trip',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Location tracking must be enabled in the Dashboard\n'
                            '• This ensures passengers can see your bus location\n'
                            '• Enable tracking before selecting your trip direction',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.blue[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Action Buttons
                  if (isTripActive) ...[
                    // Continue Trip Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0091AD),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _continueCurrentTrip,
                        child: Text(
                          'Continue Trip',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // End Trip Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _endCurrentTrip,
                        child: Text(
                          'End Trip',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Location Tracking Status Check
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('conductors')
                          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                          .limit(1)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return SizedBox.shrink();
                        }

                        final conductorData = docs.first.data() as Map<String, dynamic>;
                        final isLocationTrackingActive = conductorData['isOnline'] ?? false;

                        return Column(
                          children: [
                            // Location tracking status indicator
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isLocationTrackingActive ? Colors.green[50] : Colors.red[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isLocationTrackingActive ? Colors.green[200]! : Colors.red[200]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isLocationTrackingActive ? Icons.location_on : Icons.location_off,
                                    color: isLocationTrackingActive ? Colors.green[700] : Colors.red[700],
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isLocationTrackingActive 
                                          ? 'Location tracking is active - You can start your trip'
                                          : 'Location tracking is required - Please enable it in Dashboard first',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: isLocationTrackingActive ? Colors.green[700] : Colors.red[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            // Start New Trip Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isLocationTrackingActive 
                                      ? const Color(0xFF02A11A) 
                                      : Colors.grey[400],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: isLocationTrackingActive ? _startNewTrip : null,
                                child: Text(
                                  'Start Trip',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// QR Scan Page (reused from conductor_from.dart)
class QRScanPage extends StatefulWidget {
  @override
  _QRScanPageState createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MobileScanner(
        onDetect: (capture) async {
          if (_isProcessing) {
            print('QR scan already in progress, ignoring duplicate detection');
            return;
          }
          
          setState(() {
            _isProcessing = true;
          });
          
          final barcode = capture.barcodes.first;
          final qrData = barcode.rawValue;
          
          if (qrData != null && qrData.isNotEmpty) {
            try {
              final data = parseQRData(qrData);
              await storePreTicketToFirestore(data);
              Navigator.of(context).pop(true);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Scan failed: ${e.toString().replaceAll('Exception: ', '')}'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
              Navigator.of(context).pop(false);
            } finally {
              setState(() {
                _isProcessing = false;
              });
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid QR code: No data detected'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            setState(() {
              _isProcessing = false;
            });
          }
        },
      ),
    );
  }
}

// Helper functions (reused from conductor_from.dart)
Map<String, dynamic> parseQRData(String qrData) {
  try {
    final result = Map<String, dynamic>.from(jsonDecode(qrData));
    return result;
  } catch (e) {
    if (qrData.startsWith('PREBOOK_')) {
      final parts = qrData.split('_');
      if (parts.length >= 6) {
        return {
          'type': 'preBooking',
          'id': parts[1],
          'route': parts[2],
          'from': parts[3],
          'to': parts[4],
          'quantity': int.tryParse(parts[5]) ?? 1,
        };
      }
    }
    return _parseDartMapLiteral(qrData);
  }
}

Map<String, dynamic> _parseDartMapLiteral(String qrData) {
  String data = qrData.trim();
  if (data.startsWith('{') && data.endsWith('}')) {
    data = data.substring(1, data.length - 1);
  }
  
  Map<String, dynamic> result = {};
  List<String> pairs = [];
  int braceCount = 0;
  int startIndex = 0;
  
  for (int i = 0; i < data.length; i++) {
    if (data[i] == '{') braceCount++;
    else if (data[i] == '}') braceCount--;
    else if (data[i] == ',' && braceCount == 0) {
      pairs.add(data.substring(startIndex, i).trim());
      startIndex = i + 1;
    }
  }
  if (startIndex < data.length) {
    pairs.add(data.substring(startIndex).trim());
  }
  
  for (String pair in pairs) {
    if (pair.isEmpty) continue;
    int colonIndex = pair.indexOf(':');
    if (colonIndex == -1) continue;
    
    String key = pair.substring(0, colonIndex).trim();
    String value = pair.substring(colonIndex + 1).trim();
    result[key] = _parseValue(value);
  }
  
  return result;
}

dynamic _parseValue(String value) {
  if ((value.startsWith("'") && value.endsWith("'")) || 
      (value.startsWith('"') && value.endsWith('"'))) {
    return value.substring(1, value.length - 1);
  }
  
  if (int.tryParse(value) != null) {
    return int.parse(value);
  }
  
  if (double.tryParse(value) != null) {
    double parsed = double.parse(value);
    if (parsed == parsed.toInt()) {
      return parsed.toInt();
    }
    return parsed;
  }
  
  if (value.toLowerCase() == 'true') return true;
  if (value.toLowerCase() == 'false') return false;
  
  if (value.startsWith('[') && value.endsWith(']')) {
    String listContent = value.substring(1, value.length - 1);
    List<String> items = listContent.split(',').map((e) => e.trim()).toList();
    return items.map((item) => _parseValue(item)).toList();
  }
  
  return value;
}

Future<void> storePreTicketToFirestore(Map<String, dynamic> data) async {
  final route = data['route'];
  final type = data['type'] ?? 'preTicket';
  
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not authenticated');
  }
  
  final conductorDoc = await FirebaseFirestore.instance
      .collection('conductors')
      .where('uid', isEqualTo: user.uid)
      .limit(1)
      .get();
  
  if (conductorDoc.docs.isEmpty) {
    throw Exception('Conductor not found');
  }
  
  final conductorData = conductorDoc.docs.first.data();
  final conductorRoute = conductorData['route'];
  
  if (conductorRoute != route) {
    throw Exception('Invalid route. You are a $conductorRoute conductor but trying to scan a $route $type. Only $conductorRoute $type can be scanned.');
  }
  
  final currentPassengerCount = conductorData['passengerCount'] ?? 0;
  dynamic rawQuantity = data['quantity'];
  int quantity = 1;
  
  if (rawQuantity != null) {
    if (rawQuantity is int) {
      quantity = rawQuantity;
    } else if (rawQuantity is double) {
      quantity = rawQuantity.toInt();
    } else if (rawQuantity is String) {
      int? parsedInt = int.tryParse(rawQuantity);
      if (parsedInt != null) {
        quantity = parsedInt;
      } else {
        String cleanQuantity = rawQuantity.replaceAll(RegExp(r'[^\d.]'), '');
        if (cleanQuantity.isNotEmpty) {
          double? parsed = double.tryParse(cleanQuantity);
          if (parsed != null) {
            quantity = parsed.toInt();
          }
        }
      }
    }
  }
  
  final newPassengerCount = currentPassengerCount + quantity;
  
  if (newPassengerCount > 27) {
    throw Exception('Cannot add $quantity passengers. Bus capacity limit (27) would be exceeded. Current: $currentPassengerCount');
  }
  
  if (type == 'preBooking') {
    await _processPreBooking(data, user, conductorDoc, quantity);
  } else {
    await _processPreTicket(data, user, conductorDoc, quantity);
  }
}

Future<void> _processPreTicket(Map<String, dynamic> data, User user, QuerySnapshot conductorDoc, int quantity) async {
  final qrDataString = jsonEncode(data);
  
  QuerySnapshot existingPreTicketQuery;
  try {
    existingPreTicketQuery = await FirebaseFirestore.instance
        .collectionGroup('preTickets')
        .where('qrData', isEqualTo: qrDataString)
        .get();
  } catch (e) {
    existingPreTicketQuery = await FirebaseFirestore.instance
        .collectionGroup('preTickets')
        .get();
  }
  
  DocumentSnapshot? pendingPreTicket;
  bool hasBoarded = false;
  
  for (var doc in existingPreTicketQuery.docs) {
    final docData = doc.data() as Map<String, dynamic>?;
    if (docData == null) continue;
    
    final docQrData = docData['qrData'];
    if (docQrData != qrDataString) continue;
    
    final status = docData['status'];
    if (status == 'boarded') {
      hasBoarded = true;
      break;
    } else if (status == 'pending' && pendingPreTicket == null) {
      pendingPreTicket = doc;
    }
  }
  
  if (hasBoarded) {
    throw Exception('This pre-ticket has already been scanned and boarded.');
  }
  
  if (pendingPreTicket == null) {
    throw Exception('No pending pre-ticket found with this QR code.');
  }
  
  await pendingPreTicket.reference.update({
    'status': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
  });
  
  final conductorDocId = conductorDoc.docs.first.id;
  
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .collection('preTickets')
      .add({
        'qrData': qrDataString,
        'originalDocumentId': pendingPreTicket.id,
        'originalCollection': pendingPreTicket.reference.parent.path,
        'scannedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'qr': true,
        'status': 'boarded',
        'data': data,
      });
  
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .update({
        'passengerCount': FieldValue.increment(quantity)
      });
}

Future<void> _processPreBooking(Map<String, dynamic> data, User user, QuerySnapshot conductorDoc, int quantity) async {
  final qrDataString = jsonEncode(data);
  
  QuerySnapshot existingPreBookingQuery;
  try {
    existingPreBookingQuery = await FirebaseFirestore.instance
        .collectionGroup('preBookings')
        .where('qrData', isEqualTo: qrDataString)
        .where('status', isEqualTo: 'paid')
        .get();
  } catch (e) {
    existingPreBookingQuery = await FirebaseFirestore.instance
        .collectionGroup('preBookings')
        .get();
  }
  
  DocumentSnapshot? paidPreBooking;
  
  for (var doc in existingPreBookingQuery.docs) {
    final docData = doc.data() as Map<String, dynamic>?;
    if (docData == null) continue;
    
    final docQrData = docData['qrData'];
    if (docQrData != qrDataString) continue;
    
    if (paidPreBooking == null) {
      paidPreBooking = doc;
    }
  }
  
  if (paidPreBooking == null) {
    throw Exception('No paid pre-booking found with this QR code. Please ensure payment is completed.');
  }
  
  final preBookingData = paidPreBooking.data() as Map<String, dynamic>;
  if (preBookingData['status'] == 'boarded' || preBookingData['boardingStatus'] == 'boarded') {
    throw Exception('This pre-booking has already been scanned and boarded.');
  }
  
  await paidPreBooking.reference.update({
    'status': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
    'boardingStatus': 'boarded',
  });
  
  final conductorDocId = conductorDoc.docs.first.id;
  
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .collection('preBookings')
      .add({
        'qrData': qrDataString,
        'originalDocumentId': paidPreBooking.id,
        'originalCollection': paidPreBooking.reference.parent.path,
        'scannedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'qr': true,
        'status': 'boarded',
        'boardingStatus': 'boarded',
        'data': data,
      });
  
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .update({
        'passengerCount': FieldValue.increment(quantity)
      });
}
