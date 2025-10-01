import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'summaries_screen.dart'; // Import the new screen

class EmailSummarizerScreen extends StatefulWidget {
  const EmailSummarizerScreen({super.key});

  @override
  State<EmailSummarizerScreen> createState() => _EmailSummarizerScreenState();
}

class _EmailSummarizerScreenState extends State<EmailSummarizerScreen> with TickerProviderStateMixin {
  // Base URL for the backend is used to construct specific endpoint URLs
  static const String baseUrl = 'http://192.168.1.7:5000'; 
  
  File? selectedFile; 
  Uint8List? selectedFileBytes; 
  String? selectedFileName;
  bool isLoading = false;
  
  // Polling state
  Timer? _pollingTimer;
  String? _currentJobId;
  int _currentProgress = 0; // State variable for actual percentage (0-100)

  // Controller for the percentage text update animation (speed of progress transitions)
  late AnimationController _progressController;
  // Controller for the continuous sweeping indicator animation
  late AnimationController _sweepController; 

  @override
  void initState() {
    super.initState();
    // Progress controller: used to trigger the AnimatedBuilder for percentage text update
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), 
    );
    
    // Sweep controller: used for the looping, indeterminate background animation
    _sweepController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500), // Speed of the sweep
    );
  }

  @override
  void dispose() {
    _stopPolling();
    _progressController.dispose();
    _sweepController.dispose(); // Dispose sweep controller
    super.dispose();
  }
  
  // --- Polling Logic ---

  void _startPolling(String jobId) {
    _currentJobId = jobId;
    
    // Start the continuous sweep animation immediately
    _sweepController.repeat(reverse: false);

    // Poll every 1 second
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final statusUrl = Uri.parse('$baseUrl/status/$jobId');

      try {
        final response = await http.get(statusUrl);
        if (!mounted) return;
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final int reportedProgress = data['progress'] as int;
          
          _updateProgress(reportedProgress, data['results']);

          if (data['status'] == 'completed') {
            _stopPolling();
            
          } else if (data['status'] == 'failed') {
            _stopPolling();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Summarization failed: ${data['error']}')),
            );
            _resetLoadingState();
          }
        } else {
          if (response.statusCode == 404) {
            print('Job not found, stopping polling.');
          } else {
            print('Polling failed with status: ${response.statusCode}');
          }
          _resetLoadingState();
        }
      } catch (e) {
        print('Polling connection error: $e');
        _resetLoadingState();
      }
    });
  }
  
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _currentJobId = null;
    _sweepController.stop(); // Ensure sweep stops when polling ends
  }

  void _updateProgress(int progress, List<dynamic>? results) {
    if (!mounted) return;

    double targetValue = progress / 100.0;

    setState(() {
      _currentProgress = progress;
    });

    if (progress == 100) {
      // Final step: Snap to 100% and navigate
      _stopPolling();
      _progressController.animateTo(1.0, duration: const Duration(milliseconds: 200)).then((_) {
        if (results != null) {
          _navigateToSummaryScreen(results);
        }
      });
    } else {
      // Intermediate step: Update percentage and start the smooth animation
      // This ensures the text updates and the sweep continues smoothly.
      double nextMilestoneValue = targetValue + (0.2 * (1.0 - targetValue));
      double clampedTarget = nextMilestoneValue.clamp(_progressController.value, 0.99);

      _progressController.animateTo(
          clampedTarget,
          duration: const Duration(milliseconds: 1000), 
          curve: Curves.linear, 
      );
    }
  }
  
  void _resetLoadingState() {
    if (!mounted) return;
    _stopPolling();
    setState(() {
      _progressController.stop(); 
      _progressController.reset(); 
      isLoading = false;
      _currentProgress = 0;
    });
  }

  // --- UI and File Logic ---

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: kIsWeb, 
    );
    if (result != null) {
      final file = result.files.single;
      if (kIsWeb) {
        selectedFileBytes = file.bytes;
        selectedFileName = file.name;
        selectedFile = null;
      } else {
        selectedFile = File(file.path!);
        selectedFileName = file.name;
        selectedFileBytes = null;
      }
      setState(() {});
    }
  }

  void clearFile() {
    _resetLoadingState(); // Stop polling and reset progress UI immediately

    setState(() {
      selectedFile = null;
      selectedFileBytes = null;
      selectedFileName = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File selection cleared.')),
    );
  }

  Future<void> _navigateToSummaryScreen(final summaries) async {
    if (mounted) {
      // Ensure state is fully reset before pushing the new screen
      _progressController.stop(); 
      _progressController.reset(); 
      setState(() {
        isLoading = false;
        _currentProgress = 0;
      });
      
      // Navigate away
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SummariesScreen(summaries: summaries ?? []),
        ),
      );
    }
  }


  Future<void> summarizeFile() async {
    if (selectedFile == null && selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      _currentProgress = 0;
    });

    try {
      
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/submit_job'));

      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes('file', selectedFileBytes!, filename: selectedFileName));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', selectedFile!.path, filename: selectedFileName));
      }

      var response = await request.send();
      if (response.statusCode == 202) { // 202 Accepted means job started
        var responseData = await response.stream.bytesToString();
        final data = json.decode(responseData);
        final jobId = data['job_id'];

        // 2. Start Polling for Status
        _startPolling(jobId);

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job submission failed. Status: ${response.statusCode}')),
        );
        _resetLoadingState();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection Error: $e')),
      );
      _resetLoadingState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isFileSelected = selectedFile != null || selectedFileBytes != null;
    final buttonEnabled = isFileSelected && !isLoading;

    // Get the button's max width for the sweep animation calculation
    // NOTE: This must match the maxWidth constraint for the animation to align perfectly.
    // We use a fixed value as the ConstrainedBox limits it.
    final double buttonWidth = 500; 

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Email Summarizer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Upload Your Email Corpus',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Summarize hundreds of emails instantly using the power of Gemini.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),
                
                // Visual File Upload Area
                GestureDetector(
                  onTap: isLoading ? null : pickFile,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: isFileSelected ? primaryColor.withOpacity(0.08) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isFileSelected ? primaryColor : Colors.grey.shade400,
                        style: BorderStyle.solid,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isFileSelected ? Icons.mail_outline : Icons.cloud_upload_outlined,
                          size: 60,
                          color: isFileSelected ? Colors.green.shade700 : primaryColor,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isFileSelected ? 'File Ready for Summary' : 'Click to browse for .txt file',
                          style: TextStyle(
                            color: isFileSelected ? Colors.green.shade700 : primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (selectedFileName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    "Selected: $selectedFileName",
                                    style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Clear File Button
                                if (!isLoading)
                                  InkWell(
                                    onTap: clearFile,
                                    child: Icon(
                                      Icons.close, 
                                      size: 18, 
                                      color: primaryColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // Summarize Button with Progress Bar Effect
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: buttonEnabled ? summarizeFile : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: EdgeInsets.zero, 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      disabledBackgroundColor: primaryColor.withOpacity(0.4),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 1. Sweeping Light Animation (Continuous indeterminate signal)
                        if (isLoading)
                          ClipRRect( 
                            borderRadius: BorderRadius.circular(30),
                            child: AnimatedBuilder(
                              animation: _sweepController, 
                              builder: (context, child) {
                                // Calculate the offset to sweep the gradient fully across the button
                                final double sweepOffset = (_sweepController.value * buttonWidth * 2) - buttonWidth;
                                
                                return Transform.translate( 
                                  offset: Offset(sweepOffset, 0),
                                  child: Container(
                                    // Make the container very wide to ensure the gradient covers the entire button width during movement.
                                    width: buttonWidth * 3, 
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.0),
                                          Colors.white.withOpacity(0.35), 
                                          Colors.white.withOpacity(0.0),
                                        ],
                                        stops: const [0.4, 0.5, 0.6],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        
                        // 2. Text Label (Always on top, shows percentage when loading)
                        AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            final text = isLoading
                                ? "SUMMARIZING... ($_currentProgress%)"
                                : "SUMMARIZE EMAILS";
                            return Text(
                              text,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isFileSelected && !isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Select a file to enable the button.',
                      style: TextStyle(color: Colors.grey),
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
