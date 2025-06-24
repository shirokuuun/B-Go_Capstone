import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';

class ConductorFrom extends StatefulWidget {
  const ConductorFrom({Key? key}) : super(key: key);

  @override
  State<ConductorFrom> createState() => _ConductorFromState();
}

class _ConductorFromState extends State<ConductorFrom> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            expandedHeight: 72,
            backgroundColor: const Color(0xFF1D2B53),
            leading: Padding(
              padding: const EdgeInsets.only(top: 18.0, left: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.only(top: 22.0),
              child: Text(
                'Ticketing',
                style: GoogleFonts.bebasNeue(
                  fontSize: 25,
                  color: Colors.white,
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(top: 15.0, right: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.sos, color: Colors.redAccent),
                      iconSize: 30,
                      onPressed: () {
                        // TODO: SOS action
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      iconSize: 30,
                      onPressed: () {
                        // TODO: Camera action
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Color(0xFFE5E9F0),
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                   FutureBuilder<String>(
                    future: RouteService.fetchRoutePlaceName(),
                    builder: (context, snapshot){
                        String placeName = '';
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          placeName = '...';
                        } else if (snapshot.hasError) {
                          placeName = 'Error';
                        } else if (snapshot.hasData) {
                          placeName = snapshot.data!;
                        }
                        return Text(
                          'ROUTE: $placeName',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 25,
                            color: Colors.black,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverFillRemaining(),
        ],
      ),
    );
  }
}