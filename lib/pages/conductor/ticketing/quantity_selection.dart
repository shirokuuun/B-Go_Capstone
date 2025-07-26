import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class QuantitySelection extends StatefulWidget {

  const QuantitySelection({Key? key}) : super(key: key);

  @override
  _QuantitySelectionState createState() => _QuantitySelectionState();
}

class _QuantitySelectionState extends State<QuantitySelection> {
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Quantity', style: GoogleFonts.outfit(fontSize: 20)),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: quantity > 1 ? () => setState(() => quantity--) : null,
          ),
          Text('$quantity', style: GoogleFonts.outfit(fontSize: 20)),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => quantity++),
          ),
        ],
      ),
       actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), 
          child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 14)),
        ),
        ElevatedButton(
           onPressed: () {
            Navigator.of(context).pop({'quantity': quantity}); 
          }, 
          child: Text('Confirm', style: GoogleFonts.outfit(fontSize: 14)),
        ),
      ],
    );
  }
}

class DiscountSelection extends StatefulWidget {
  final int quantity;
  const DiscountSelection({super.key, required this.quantity});

  @override
  State<DiscountSelection> createState() => _DiscountSelectionState();
}

class _DiscountSelectionState extends State<DiscountSelection> {
  final List<String> fareTypes = ['Regular', 'Student', 'PWDs', 'Senior'];
  late List<String> selectedLabels;

  @override
  void initState() {
    super.initState();
    selectedLabels = List.generate(widget.quantity, (index) => 'Regular');
  }

  double getDiscountValue(String type) {
    switch (type) {
      case "Student":
      case "Senior":
      case "PWDs":
        return 0.20;
      case "Regular":
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
     return AlertDialog(
      title: Text(
        'Select Discount',
        style: GoogleFonts.outfit(fontSize: 20),
      ),
      content: SizedBox(
        width: 350,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < widget.quantity; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Passenger ${i + 1}:',
                          style: GoogleFonts.outfit(fontSize: 16),
                        ),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: selectedLabels[i],
                          style: GoogleFonts.outfit(color: Colors.black),
                          underline: Container(),
                          items: fareTypes
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedLabels[i] = val!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            "Cancel",
            style: GoogleFonts.outfit(fontSize: 14),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            List<double> discounts =
                selectedLabels.map(getDiscountValue).toList();
            Navigator.of(context).pop({
              'discounts': discounts,
              'fareTypes': selectedLabels,
            });
          },
          child: Text(
            "Confirm",
            style: GoogleFonts.outfit(fontSize: 14),
          ),
        ),
      ],
    );
  }
}


