
import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'dart:io';

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
    final title = 'WebSocket Demo';
    return MaterialApp(
      title: title,
      home: MyHomePage(
        title: title,
        channel: IOWebSocketChannel.connect('wss://api.rev.ai/speechtotext/v1alpha/stream?access_token=02QP0lhYTj7-5zcCus1RDdN1UL9Wt7jQ7JjEGII9w6Layk9Z1Icu8OEXG_aAgWcXEKgPVVAK6IjMS1GBitw7EK9tk3klA&content_type=audio/x-raw;layout=interleaved;rate=44100;format=U8;channels=1'),
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

  void _record() {
    setState(() {
      stream = microphone(sampleRate: 44100);
      widget.channel.sink.addStream(stream);
      // Start listening to the stream
      // listener = stream.listen((samples) => print(samples));
    });
  }

  void _stopRecord() {
    setState(() {
      listener.cancel();
    });
  }

  Future<List<Field>> _fetchQuestions() async {
    var request = new http.MultipartRequest('POST', Uri.parse('http://1f3827b2.ngrok.io/questions'));
    request.files.add(MultipartFile.fromBytes(
      'file',
      imageBytes,
    ));

    final response = await request.send();

    Completer<List<Field>> c = new Completer();
    response.stream.transform(utf8.decoder).transform(json.decoder).listen((value) {
      dynamic data = value;
      final List responseJson = data['fields'];
      c.complete(responseJson.map((m) => new Field.fromJson(m)).toList());
    });

    return c.future;
  }

  Future<Uint8List> _perspectiveImage(File image) async {
    var request = new http.MultipartRequest('POST', Uri.parse('http://1f3827b2.ngrok.io/perspective'));
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

    for (Field question in questions) {
      String prompt = (question.type == 'CHECKBOX' ? 'yes or no: ' : '') + question.prompt;

      // read prompt

      if (question.type == 'SECTION') continue;

      String answer = ''; // get and store the answer

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
              stream: widget.channel.stream,
              builder: (context, snapshot) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(snapshot.hasData ? '${snapshot.data}' : 'no data'),
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
            Text(questions == null ? 'No questions' : questions.map((field) {
              return field.id;
            }).join('; ')),
            new FlatButton(
                onPressed: _choose,
                child: new Text("Upload image")
            ),
            imageBytes == null ? Text('No Image Selected') : Image.memory(imageBytes),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendMessage,
        tooltip: 'Send message',
        child: Icon(Icons.send),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _sendMessage() async {
    debugPrint('CLICKED');
  }

  @override
  void dispose() {
    widget.channel.sink.close();
    super.dispose();
  }
}
