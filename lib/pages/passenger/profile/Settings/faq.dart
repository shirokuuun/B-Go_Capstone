import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({Key? key}) : super(key: key);

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  final List<Map<String, String>> _faqs = [
    {
      'question': 'What is the B-Go app?',
      'answer':
          'B-Go is a mobile application designed to help you track, reserve, and pay for bus rides in Batangas.'
    },
    {
      'question': 'Is B-Go available on Android and iPhone?',
      'answer': 'Yes, B-Go is available for Android. We\'re working on releasing an iOS version soon.'
    },
    {
      'question': 'How do I know when the next bus will arrive at my location?',
      'answer':
          'You can view real-time bus arrival information within the app on the main dashboard or route page.'
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
          'B-Go uses GPS technology to track the location of buses in real time.'
    },
    {
      'question': 'What if my bus is delayed?',
      'answer':
          'If your bus is delayed, the app will update the estimated arrival time automatically.'
    },
    {
      'question': 'Can I pay for my ticket using the app?',
      'answer': 'Yes, B-Go supports in-app payments for your convenience.'
    },
    {
      'question': 'Is B-Go free to use?',
      'answer':
          'Yes, downloading and using the B-Go app is free. You only pay for your bus tickets.'
    },
    {
      'question': 'Who do I contact if I encounter problems with the app?',
      'answer':
          'You can contact our support team through our email support@bgo-batangas.com.'
    },
    {
      'question': 'Will the app work without internet?',
      'answer':
          'You need an internet connection to access live data like bus tracking and seat availability. Offline use is limited.'
    },
    {
      'question': 'Can I use B-Go for buses outside Batangas?',
      'answer':
          'Currently, B-Go is focused on Batangas routes. Please check the app for updates on expanded coverage.'
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
    final width = MediaQuery.of(context).size.width;
    final cyan = const Color(0xFF0091AD);
    final paddingH = width * 0.05;
    final fontSizeTitle = width * 0.05;
    final fontSizeQ = width * 0.045;
    final fontSizeA = width * 0.041;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: cyan,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Colors.black, size: fontSizeTitle + 2),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'FAQs',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: fontSizeTitle,
          ),
        ),
      ),
      body: ListView.separated(
        padding:
            EdgeInsets.symmetric(vertical: width * 0.04, horizontal: paddingH),
        itemCount: _faqs.length,
        separatorBuilder: (_, __) => SizedBox(height: width * 0.03),
        itemBuilder: (context, i) {
          final faq = _faqs[i];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(width * 0.03),
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
                borderRadius: BorderRadius.circular(width * 0.03),
                onTap: () {
                  setState(() {
                    _expanded[i] = !_expanded[i];
                  });
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      vertical: width * 0.045, horizontal: width * 0.04),
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
                                fontSize: fontSizeQ,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Icon(
                            _expanded[i]
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Colors.grey,
                            size: fontSizeQ + 4,
                          ),
                        ],
                      ),
                      if (_expanded[i]) ...[
                        SizedBox(height: width * 0.025),
                        Text(
                          faq['answer']!,
                          style: GoogleFonts.outfit(
                            fontSize: fontSizeA,
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
