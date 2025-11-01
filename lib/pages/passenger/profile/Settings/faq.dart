import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({Key? key}) : super(key: key);

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  final List<Map<String, String>> _faqs = [
    {
      'question': 'What is the BusGo app?',
      'answer':
          'BusGo is a mobile application designed to help you track, reserve, and pay for bus rides in Batangas.'
    },
    {
      'question': 'Is BusGo available on Android and iPhone?',
      'answer': 'Yes, BusGo is available for Android. We\'re working on releasing an iOS version soon.'
    },
    {
      'question': 'How do I know when the next bus will arrive at my location?',
      'answer':
          'You can view real-time bus arrival information within the app on the main dashboard.'
    },
    {
      'question': 'How do I check if the bus is full?',
      'answer':
          'The app displays the current occupancy of each bus, so you can see if there are available seats before boarding or reserving.'
    },
    {
      'question': 'Can I reserve a seat through the app?',
      'answer':
          'Yes, you can reserve a seat in advance using the pre-booking feature in the app.'
    },
    {
      'question': 'How does the app track the bus?',
      'answer':
          'BusGo uses GPS technology to track the location of buses in real time.'
    },
    {
      'question': 'What if my bus is delayed?',
      'answer':
          'If your bus is delayed, the app will update the estimated arrival time automatically.'
    },
    {
      'question': 'Can I pay for my ticket using the app?',
      'answer': 'Yes, BusGo supports in-app payments for your convenience.'
    },
    {
      'question': 'Is BusGo free to use?',
      'answer':
          'Yes, downloading and using the BusGo app is free. You only pay for your bus tickets.'
    },
    {
      'question': 'Who do I contact if I encounter problems with the app?',
      'answer':
          'You can contact our support team through our email batrascoservices@gmail.com.'
    },
    {
      'question': 'Will the app work without internet?',
      'answer':
          'You need an internet connection to access live data like bus tracking and seat availability. Offline use is limited.'
    },
    {
      'question': 'Can I use BusGo for buses outside Batangas?',
      'answer':
          'Currently, BusGo is focused on Batangas routes. Please check the app for updates on expanded coverage.'
    },
  ];

  List<bool> _expanded = [];

  @override
  void initState() {
    super.initState();
    _expanded = List.generate(_faqs.length, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    // Responsive sizing
    final appBarFontSize = isMobile
        ? 18.0
        : isTablet
            ? 20.0
            : 24.0;
    final questionFontSize = isMobile
        ? 14.0
        : isTablet
            ? 16.0
            : 18.0;
    final answerFontSize = isMobile
        ? 13.0
        : isTablet
            ? 15.0
            : 17.0;
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 24.0;
    final verticalPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;
    final cardSpacing = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;

    final cyan = const Color(0xFF0091AD);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: cyan,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Colors.white, size: appBarFontSize + 2),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'FAQs',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: appBarFontSize,
          ),
        ),
      ),
      body: ListView.separated(
        padding:
            EdgeInsets.symmetric(vertical: verticalPadding, horizontal: horizontalPadding),
        itemCount: _faqs.length,
        separatorBuilder: (_, __) => SizedBox(height: cardSpacing),
        itemBuilder: (context, i) {
          final faq = _faqs[i];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _expanded[i] = !_expanded[i];
                  });
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      vertical: verticalPadding, horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              faq['question']!,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w500,
                                fontSize: questionFontSize,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Icon(
                            _expanded[i]
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.grey,
                            size: questionFontSize + 4,
                          ),
                        ],
                      ),
                      if (_expanded[i]) ...[
                        SizedBox(height: 8),
                        Text(
                          faq['answer']!,
                          style: GoogleFonts.outfit(
                            fontSize: answerFontSize,
                            color: Colors.black87,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
