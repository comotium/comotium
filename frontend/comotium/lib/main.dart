
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'dart:io';

import 'package:text_to_speech_api/text_to_speech_api.dart';
import 'package:audioplayer/audioplayer.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mic_stream/mic_stream.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';

import 'package:http/http.dart' as http;

import 'Field.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final title = 'Cumotium';
    return MaterialApp(
      title: title,
      home: MyHomePage(
        title: title,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  final WebSocketChannel channel;

  MyHomePage({Key key, @required this.title, @required this.channel})
      : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController _controller = TextEditingController();
  Stream<List<int>> stream;
  StreamSubscription<List<int>> listener;
  Uint8List imageBytes;
  List<Field> questions;
  Map<String, String> answers;
  AudioPlayer audioPlugin = new AudioPlayer();
  var channel = IOWebSocketChannel.connect('wss://api.rev.ai/speechtotext/v1alpha/stream?access_token=02QP0lhYTj7-5zcCus1RDdN1UL9Wt7jQ7JjEGII9w6Layk9Z1Icu8OEXG_aAgWcXEKgPVVAK6IjMS1GBitw7EK9tk3klA&content_type=audio/x-raw;layout=interleaved;rate=44100;format=U8;channels=1');
  TextToSpeechService service = TextToSpeechService(
      'AIzaSyA1QMxxgEBWpTmh7aSi1GXRcERIDprkluE');

  void _record() {
    setState(() {
      stream = microphone(sampleRate: 44100);
      // Start listening to the stream
      channel = IOWebSocketChannel.connect('wss://api.rev.ai/speechtotext/v1alpha/stream?access_token=02QP0lhYTj7-5zcCus1RDdN1UL9Wt7jQ7JjEGII9w6Layk9Z1Icu8OEXG_aAgWcXEKgPVVAK6IjMS1GBitw7EK9tk3klA&content_type=audio/x-raw;layout=interleaved;rate=44100;format=U8;channels=1');
      listener = stream.listen((samples) => channel.sink.add(samples));
      // widget.channel.sink.addStream(stream);
    });
  }

  void _stopRecord() {
    setState(() {});
  }

  Future<List<Field>> _fetchQuestions() async {
    var request = new http.MultipartRequest(
        'POST', Uri.parse('http://d0e81c45.ngrok.io/questions'));
    request.files.add(MultipartFile.fromBytes(
      'file',
      imageBytes,
    ));

    final response = await request.send();

    Completer<List<Field>> c = new Completer();
    response.stream.transform(utf8.decoder).transform(json.decoder).listen((
        value) {
      dynamic data = value;
      final List responseJson = data['fields'];
      c.complete(responseJson.map((m) => new Field.fromJson(m)).toList());
    });

    return c.future;
  }

  Future<Uint8List> _perspectiveImage(File image) async {
    var request = new http.MultipartRequest(
        'POST', Uri.parse('http://d0e81c45.ngrok.io/perspective'));
    request.files.add(await MultipartFile.fromPath(
      'file',
      image.path,
    ));

    final response = await request.send();

    debugPrint('getting bytes');
    return await response.stream.toBytes();
  }

  Future<Map<String, String>> _askQuestions() async {
    Map<String, String> answers = new Map();

    bool end = false;

    for (int i = 0; i < questions.length; i++) {
      Field question = questions[i];

      if (end) {
        answers.putIfAbsent(question.id, () {
          return '';
        });
        continue;
      }

      String prompt = (question.type == 'CHECKBOX' ? 'yes or no: ' : '') +
          question.prompt;

      print('start' + prompt);
      await _play(prompt);
      print('finish' + prompt);

      if (question.type == 'SECTION') continue;


      Stream<List<int>> stream = microphone(sampleRate: 44100);
      // Start listening to the stream

      Completer c = new Completer();
      IOWebSocketChannel channel = IOWebSocketChannel.connect('wss://api.rev.ai/speechtotext/v1alpha/stream?access_token=02QP0lhYTj7-5zcCus1RDdN1UL9Wt7jQ7JjEGII9w6Layk9Z1Icu8OEXG_aAgWcXEKgPVVAK6IjMS1GBitw7EK9tk3klA&content_type=audio/x-raw;layout=interleaved;rate=44100;format=U8;channels=1');
      StreamSubscription<List<int>> listener = stream.listen((samples) => channel.sink.add(samples));
      channel.stream.listen((value) {
        var data = jsonDecode(value);

        if (data['type'] == 'final') {
          listener.cancel();
          channel.sink.close();

          String output = '';
          for (dynamic element in data['elements']) {
            print(element);
            String value = element['value'];
            print(value);
            String type = element['type'];
            print(type);
            if (type != 'punct') output = output + ' ' + value;
          }

          debugPrint(output);
          if (!c.isCompleted) {
            c.complete(output);
          }
        }
      });

      String answer = await c.future;

      switch (answer.trim().toLowerCase()) {
        case 'skip':
          break;
        case '':
        case 'repeat':
          i -= 1;
          break;
        case 'back':
          i -= 2;
          break;
        case 'and':
        case 'end':
          end = true;
          break;
      }

      answers.putIfAbsent(question.id, () {
        return answer;
      });
    }

    return answers;
  }

  void _choose() async {
    File image = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    Uint8List imageBytes = await _perspectiveImage(image);
    debugPrint('got bytes');

    setState(() {
      this.imageBytes = imageBytes;
    });

    final questions = await _fetchQuestions();

    setState(() {
      this.questions = questions;
    });

    final answers = await _askQuestions();

    setState(() {
      this.answers = answers;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _play(String source) async {
    File query = await service.textToSpeech(
        text: source,
        voiceName: 'en-GB-Wavenet-A',
        audioEncoding: 'MP3',
        languageCode: 'en-GB'
    );

    Completer c = new Completer();
    audioPlugin.onPlayerStateChanged.listen((s) {
      if (s == AudioPlayerState.STOPPED && !c.isCompleted) {
        c.complete();
      }
    });

    await audioPlugin.play(query.path, isLocal: true);
    return c.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Form(
                  child: TextFormField(
                    controller: _controller,
                    decoration: InputDecoration(labelText: 'Send a message'),
                  ),
                ),
                StreamBuilder(
                  stream: channel.stream, builder: (context, snapshot) {
                  if (snapshot.data != null) {
                    dynamic jsonData = json.decode(snapshot.data);

                    if (jsonData['type'] == 'final') {
                      String output = (jsonData['elements']
                          .map((element) {
                        return element['value'];
                      }).join(' '));
                      debugPrint(output);
                      debugPrint('');
                      debugPrint('');
                      debugPrint('');
                      debugPrint('STOP=============================');
                      debugPrint('');
                      debugPrint('');
                      debugPrint('');

                      listener.cancel();
                      channel = null;
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                        snapshot.hasData ? '${snapshot.data}' : 'no data'),
                  );
                },
                ),
                new FlatButton(
                    onPressed: _record,
                    child: new Text("Record Stream")
                ),
                new FlatButton(
                    onPressed: _stopRecord,
                    child: new Text("Stop Recording")
                ),
                Text(
                    questions == null ? 'No questions' : questions.map((field) {
                      return field.id;
                    }).join('; ')),
                imageBytes == null ? Text('No Image Selected') : Image.memory(
                    imageBytes),
                new Material(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(24.0),
                    child: new FlatButton(
                        onPressed: _choose,
                        child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Icon(
                                  Icons.file_upload, color: Colors.white,
                                  size: 30.0),
                            )
                        )
                    )
                ),
              ]
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _sendMessage,
          tooltip: 'Send message',
          child: Icon(Icons
              .send), // This trailing comma makes auto-formatting nicer for build methods.
        ));
  }

  void _sendMessage() async {
    debugPrint('CLICKED');
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }
}
