import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  late AudioPlayer audioPlayer;
  late AudioRecorder audioRecord;
  bool isRecording = false;
  String? audioPath;
  late Uuid uid;
  bool isDoneRecording = false;
  List<Recording> recordedList = [];

  @override
  void initState() {
    super.initState();
    audioPlayer = AudioPlayer();
    audioRecord = AudioRecorder();
    uid = const Uuid();
  }

  @override
  void dispose() {
    super.dispose();
    audioRecord.dispose();
    audioPlayer.dispose();
  }

  // start recording
  Future<void> startRecording() async {
    // Check and request permission if needed
    if (await audioRecord.hasPermission()) {
      // Start recording to file
      try {
        final externalDir = await getExternalStorageDirectory();
        final recordsDir = Directory('${externalDir?.path}/records');
        await recordsDir.create(
          recursive: true,
        ); // Create directory if it doesn't exist
        final filePath = '${recordsDir.path}/${uid.v4()}.wav';

        await audioRecord.start(const RecordConfig(), path: filePath);

        setState(() {
          isRecording = true;
          isDoneRecording = false;
        });
      } catch (e) {
        print('error recording');
      }
    } else {
      print('No Permission');
    }
  }

  // stop recording
  Future<void> stopRecording() async {
    // Stop recording to file
    try {
      final path = await audioRecord.stop();
      String currentDateTime =
          DateFormat('E, MMM d, y h:mma').format(DateTime.now());

      // Save the recording to the list
      recordedList.add(
          Recording(id: uid.v4(), filePath: path!, dateTime: currentDateTime));

      setState(() {
        isRecording = false;
        isDoneRecording = true;
      });
    } catch (e) {
      print('error stopping recording');
    }
  }

  // playPause Recording
  Future<void> playPauseRecording(
    int index,
    String id,
  ) async {
    await audioPlayer.stop();
    // Toggle play/pause state for the recording

    // Create a new list of recordings with updated isPlaying state
    List<Recording> newRecords = List.from(recordedList);
    newRecords = newRecords.map((record) {
      if (record.id != id) {
        record.isPlaying = false;
      }
      return record;
    }).toList();

    // Toggle isPlaying for the selected recording
    newRecords[index].toggleIsPlaying();

    setState(() {
      // Set the old recordings to the new recordings
      recordedList = newRecords;
    });

    if (recordedList[index].isPlaying) {
      // Start playing the recording
      Source urlSource = UrlSource(recordedList[index].filePath);
      await audioPlayer.play(urlSource);

      // Listen for playback completion to update the UI
      audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          recordedList[index].isPlaying = false;
        });
      });
    } else {
      // Pause the playback
      await audioPlayer.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Record Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () => isRecording ? stopRecording() : startRecording(),
              child: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
            Text(
              isRecording ? 'Started Recording' : '',
            ),
            Expanded(
              child: ListView.builder(
                itemCount: recordedList.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.mic_none),
                    title: Text('Recording ${index + 1}'),
                    subtitle: Text(recordedList[index].dateTime),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          icon: Icon(
                            recordedList[index].isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                          onPressed: () =>
                              playPauseRecording(index, recordedList[index].id),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.translate,
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Recording {
  String id;
  String filePath;
  String dateTime;
  bool isPlaying;

  Recording({
    required this.id,
    required this.filePath,
    required this.dateTime,
    this.isPlaying = false,
  });

  void toggleIsPlaying() {
    isPlaying = !isPlaying;
  }
}
