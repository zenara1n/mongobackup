import 'dart:convert';
import 'dart:ui'; // Import for BackdropFilter
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MongoDB Backup & Restore',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MongoBackupRestoreApp(),
    );
  }
}

class MongoBackupRestoreApp extends StatefulWidget {
  @override
  _MongoBackupRestoreAppState createState() => _MongoBackupRestoreAppState();
}

class _MongoBackupRestoreAppState extends State<MongoBackupRestoreApp> {
  final TextEditingController uriController = TextEditingController();
  final TextEditingController backupPathController = TextEditingController();
  final TextEditingController restorePathController = TextEditingController();

  String outputLog = ""; // To show logs to the user
  bool isLoading = false; // To control loading indicator
  String dialogTitle = ""; // Title for the loading dialog
  bool isMongodumpInstalled = false; // Check for mongodump installation
  String mongodumpVersion = ""; // Store the version of mongodump

  @override
  void initState() {
    super.initState();
    _getBackupPath().then((path) {
      backupPathController.text = path; // Set default backup path
    });
    _checkMongodumpInstallation(); // Check if mongodump is installed on startup
  }

  // Function to show toast messages
  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  // Function to show a dialog with a message
  void showDialogMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Function to check for mongodump installation
  Future<void> _checkMongodumpInstallation() async {
    try {
      // Try to execute the command
      var result = await Process.run('mongodump', ['--version']);
      if (result.exitCode == 0) {
        setState(() {
          isMongodumpInstalled = true;
          mongodumpVersion = result.stdout.toString();
        });
        showToast("mongodump installed: $mongodumpVersion");
      } else {
        // If the command fails, show installation instructions
        _showInstallationInstructions();
      }
    } catch (e) {
      // If there's an error, show installation instructions
      _showInstallationInstructions();
    }
  }

  // Function to show installation instructions
  void _showInstallationInstructions() {
    showDialogMessage(
      "Installation Required",
      "Please install mongodump to use this application.\n\n"
          "For installation instructions:\n"
          " - **macOS**: Use Homebrew: `brew tap mongodb/brew && brew install mongodb-database-tools`\n"
          " - **Windows**: Download the MongoDB Database Tools from the official MongoDB website.\n"
          " - **Linux**: Use your package manager, e.g., `sudo apt-get install mongodb-database-tools` for Ubuntu.",
    );
  }

  // Function to open the backup folder in Finder
  Future<void> openBackupFolder(String path) async {
    await Process.start('open', [path]);
  }

  // Function to run backup
  Future<void> runBackup(String uri, String outputPath) async {
    setState(() {
      outputLog = ""; // Clear old logs
      isLoading = true;
      dialogTitle = "Making Backup...";
    });
    showLoadingDialog();

    try {
      // Start the backup process
      var process = await Process.start(
        'mongodump',
        ['--uri', uri, '-o', outputPath],
        mode: ProcessStartMode.normal,
      );

      // Capture output and error streams
      process.stdout.transform(const Utf8Decoder()).listen((data) {
        setState(() {
          outputLog += data; // Append live log
        });
      });
      process.stderr.transform(const Utf8Decoder()).listen((data) {
        setState(() {
          outputLog += data;
        });
      });

      // Wait for the process to complete
      var exitCode = await process.exitCode;

      // Check the exit code and update the output log
      String message = (exitCode == 0)
          ? "Backup successful."
          : "Backup failed with exit code $exitCode.";
      showToast(message);
      Navigator.of(context).pop(); // Close loading dialog
      showDialogMessage("Backup Status", message);

      // Open backup folder
      if (exitCode == 0) {
        openBackupFolder(outputPath);
      }
    } catch (e) {
      // Handle exceptions
      showToast("Error during backup: $e");
      Navigator.of(context).pop(); // Close loading dialog
      showDialogMessage("Error during backup", "Error during backup: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Function to run restore
  Future<void> runRestore(String uri, String backupPath) async {
    setState(() {
      outputLog = ""; // Clear old logs
      isLoading = true;
      dialogTitle = "Restoring Data...";
    });
    showLoadingDialog();

    try {
      // Start the restore process
      var process = await Process.start(
        'mongorestore',
        ['--uri', uri, backupPath],
        mode: ProcessStartMode.normal,
      );

      // Capture output and error streams
      process.stdout.transform(const Utf8Decoder()).listen((data) {
        setState(() {
          outputLog += data; // Append live log
        });
      });
      process.stderr.transform(const Utf8Decoder()).listen((data) {
        setState(() {
          outputLog += "$data"; // Append error log
        });
      });

      // Wait for the process to complete
      var exitCode = await process.exitCode;

      // Check the exit code and update the output log
      String message = (exitCode == 0)
          ? "Restore successful."
          : "Restore failed with exit code $exitCode.";
      showToast(message);
      Navigator.of(context).pop(); // Close loading dialog
      showDialogMessage("Restore Status", message);
    } catch (e) {
      // Handle exceptions
      showToast("Error during restore: $e");
      Navigator.of(context).pop(); // Close loading dialog
      showDialogMessage("Error during restore", "Error during restore: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Function to get backup path
  Future<String> _getBackupPath() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    return appDocDir.path; // Use application documents directory
  }

  // Function to show loading dialog with live logs
  void showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissal on tap outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(dialogTitle),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Please wait..."),
            ],
          ),
        );
      },
    );
  }

  // Function to show installation instructions in a dialog
  void showInstallationInstructions() {
    showDialogMessage(
      "Installation Instructions",
      "To install mongodump, follow the instructions for your platform:\n\n"
          " - macOS: Use Homebrew:\n"
          "     brew tap mongodb/brew && brew install mongodb-database-tools\n\n"
          " - Windows: Download the MongoDB Database Tools from the official MongoDB website.\n\n"
          " - Linux: Use your package manager:\n"
          "     sudo apt-get install mongodb-database-tools` for Ubuntu.",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: uriController,
                        decoration: const InputDecoration(
                          labelText: 'MongoDB API',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: backupPathController,
                        decoration: const InputDecoration(
                          labelText: 'Backup Path',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isLoading || !isMongodumpInstalled
                          ? null // Disable button if loading or not installed
                          : () {
                              runBackup(uriController.text,
                                  backupPathController.text);
                            },
                      child: const Text('Backup'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: restorePathController,
                        decoration: const InputDecoration(
                          labelText: 'Restore Path',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isLoading || !isMongodumpInstalled
                          ? null // Disable button if loading or not installed
                          : () {
                              runRestore(uriController.text,
                                  restorePathController.text);
                            },
                      child: const Text('Restore'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isMongodumpInstalled)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('mongodump is installed',
                            style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('mongodump is NOT installed',
                            style: TextStyle(color: Colors.red)),
                        IconButton(
                          icon:
                              const Icon(Icons.help_outline, color: Colors.red),
                          onPressed: () => showInstallationInstructions(),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Output Log:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(outputLog),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
