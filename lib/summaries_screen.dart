import 'package:email_summarizer/emailsummarizerscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 

class SummariesScreen extends StatelessWidget {
  final List<dynamic> summaries;

  const SummariesScreen({super.key, required this.summaries});

  
  void _copySummary(BuildContext context, List<dynamic> points) {
    
    final textToCopy = points.map((point) => "• $point").join('\n');
    
    
    Clipboard.setData(ClipboardData(text: textToCopy)).then((_) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary copied to clipboard!')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Colors.green.shade700; 

    return Scaffold(
      
      appBar: AppBar(
        title: const Text('Summarized Insights'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => EmailSummarizerScreen()),
        );
          },
        ),
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
                  final summaryPoints = summary['summary'] is List ? summary['summary'] as List<dynamic> : [];
                  
                  return Card(
                    elevation: 6, 
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.person_pin, color: primaryColor, size: 18),
                                        const SizedBox(width: 10),
                                        Expanded( 
                                          child: Text(
                                            summary['sender'] ?? 'Unknown Sender',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: primaryColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2, 
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.subject, color: Colors.grey.shade600, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            summary['subject'] ?? 'No Subject Provided',
                                            style: Theme.of(context).textTheme.titleMedium,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2, 
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),


                              SizedBox(
                                width: 40, 
                                child: IconButton(
                                  icon: Icon(Icons.copy, color: primaryColor),
                                  tooltip: 'Copy Summary to Clipboard',
                                  
                                  onPressed: summaryPoints.isNotEmpty 
                                    ? () => _copySummary(context, summaryPoints)
                                    : null, 
                                ),
                              ),
                            ],
                          ),
                          
                          const Divider(height: 30, thickness: 1.5, color: Colors.black12),
                          
                         
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
