import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'summaries_screen.dart';

class EmailSummarizerScreen extends StatefulWidget {
  const EmailSummarizerScreen({super.key});

  @override
  State<EmailSummarizerScreen> createState() => _EmailSummarizerScreenState();
}

class _EmailSummarizerScreenState extends State<EmailSummarizerScreen>
    with TickerProviderStateMixin {
  static const String baseUrl = 'http://192.168.1.7:5000';

  File? selectedFile;
  Uint8List? selectedFileBytes;
  String? selectedFileName;
  bool isLoading = false;

  Timer? _pollingTimer;
  int _currentProgress = 0;
  late AnimationController _progressController;
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _stopPolling();
    _progressController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  void _startPolling(String jobId) {
    _sweepController.repeat(reverse: false);

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
    _sweepController.stop();
  }

  void _updateProgress(int progress, List<dynamic>? results) {
    if (!mounted) return;

    double targetValue = progress / 100.0;

    setState(() {
      _currentProgress = progress;
    });

    if (progress == 100) {
      _stopPolling();
      _progressController
          .animateTo(1.0, duration: const Duration(milliseconds: 200))
          .then((_) {
            if (results != null) {
              _navigateToSummaryScreen(results);
            }
          });
    } else {
      double nextMilestoneValue = targetValue + (0.2 * (1.0 - targetValue));
      double clampedTarget = nextMilestoneValue.clamp(
        _progressController.value,
        0.99,
      );

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
    _resetLoadingState();

    setState(() {
      selectedFile = null;
      selectedFileBytes = null;
      selectedFileName = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('File selection cleared.')));
  }

  Future<void> _navigateToSummaryScreen(final summaries) async {
    if (mounted) {
      _progressController.stop();
      _progressController.reset();
      setState(() {
        isLoading = false;
        _currentProgress = 0;
      });

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
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/submit_job'),
      );

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            selectedFileBytes!,
            filename: selectedFileName,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            selectedFile!.path,
            filename: selectedFileName,
          ),
        );
      }

      var response = await request.send();
      if (response.statusCode == 202) {
        var responseData = await response.stream.bytesToString();
        final data = json.decode(responseData);
        final jobId = data['job_id'];
        _startPolling(jobId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Job submission failed. Status: ${response.statusCode}',
            ),
          ),
        );
        _resetLoadingState();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection Error: $e')));
      _resetLoadingState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isFileSelected = selectedFile != null || selectedFileBytes != null;
    final buttonEnabled = isFileSelected && !isLoading;

    final double buttonWidth = 500;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Email Summarizer')),
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),

                GestureDetector(
                  onTap: isLoading ? null : pickFile,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color:
                          isFileSelected
                              ? primaryColor.withOpacity(0.08)
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isFileSelected
                                ? primaryColor
                                : Colors.grey.shade400,
                        style: BorderStyle.solid,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isFileSelected
                              ? Icons.mail_outline
                              : Icons.cloud_upload_outlined,
                          size: 60,
                          color:
                              isFileSelected
                                  ? Colors.green.shade700
                                  : primaryColor,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isFileSelected
                              ? 'File Ready for Summary'
                              : 'Click to browse for .txt file',
                          style: TextStyle(
                            color:
                                isFileSelected
                                    ? Colors.green.shade700
                                    : primaryColor,
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black54,
                                    ),
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
                        if (isLoading)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: AnimatedBuilder(
                              animation: _sweepController,
                              builder: (context, child) {
                                final double sweepOffset =
                                    (_sweepController.value * buttonWidth * 2) -
                                    buttonWidth;

                                return Transform.translate(
                                  offset: Offset(sweepOffset, 0),
                                  child: Container(
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

                        AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            final text =
                                isLoading
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
