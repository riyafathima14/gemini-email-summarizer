import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // REQUIRED for Clipboard

class SummariesScreen extends StatelessWidget {
  final List<dynamic> summaries;

  const SummariesScreen({super.key, required this.summaries});

  // Helper function to copy summary points to clipboard
  void _copySummary(BuildContext context, List<dynamic> points) {
    // Format the list of points into a clean, readable string
    final textToCopy = points.map((point) => "• $point").join('\n');
    
    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: textToCopy)).then((_) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary copied to clipboard!')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Colors.green.shade700; // Use green for action/check items

    return Scaffold(
      // AppBar is themed via main.dart
      appBar: AppBar(
        title: const Text('Summarized Insights'),
      ),
      body: summaries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  "No summaries were generated. Please check the format of your uploaded file and try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: summaries.length,
                itemBuilder: (context, index) {
                  final summary = summaries[index];
                  // Ensure 'summary' is a List<String> or default to empty list if null/wrong type
                  final summaryPoints = summary['summary'] is List ? summary['summary'] as List<dynamic> : [];
                  
                  return Card(
                    elevation: 6, // Increased shadow for a modern look
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row (Sender Info + Copy Button)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Sender & Subject Info Column (Expanded to take available space)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Sender (Highlighted)
                                    Row(
                                      children: [
                                        // ICON SIZE REDUCED FOR SPACE
                                        Icon(Icons.person_pin, color: primaryColor, size: 18),
                                        const SizedBox(width: 10),
                                        // Text is expanded to use max space before truncation
                                        Expanded( 
                                          child: Text(
                                            summary['sender'] ?? 'Unknown Sender',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: primaryColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2, // <-- MODIFIED: Allow two lines
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    
                                    // Subject (Secondary info)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.subject, color: Colors.grey.shade600, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            summary['subject'] ?? 'No Subject Provided',
                                            style: Theme.of(context).textTheme.titleMedium,
                                            overflow: TextOverflow.ellipsis, // Ensure subject also truncates
                                            maxLines: 2, // <-- MODIFIED: Allow two lines
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // **Copy Button (Fixed Size)**
                              SizedBox(
                                width: 40, // Fixed width ensures the button never causes overflow
                                child: IconButton(
                                  icon: Icon(Icons.copy, color: primaryColor),
                                  tooltip: 'Copy Summary to Clipboard',
                                  // Only allow copying if there are points to copy
                                  onPressed: summaryPoints.isNotEmpty 
                                    ? () => _copySummary(context, summaryPoints)
                                    : null, // Disabled if no summary points exist
                                ),
                              ),
                            ],
                          ),
                          
                          const Divider(height: 30, thickness: 1.5, color: Colors.black12),
                          
                          // Summary Points (Bulleted List)
                          Text(
                            "Key Takeaways:",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          ...summaryPoints.map<Widget>((point) =>
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.check_circle, color: accentColor, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(point)),
                                  ],
                                ),
                              )
                          ).toList(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
