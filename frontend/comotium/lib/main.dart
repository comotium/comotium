
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    final title = '';
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
  Uint8List imageBytes;
  List<Field> questions;
  Map<String, String> answers;
  AudioPlayer audioPlugin = new AudioPlayer();
  TextToSpeechService service = TextToSpeechService(
      'AIzaSyA1QMxxgEBWpTmh7aSi1GXRcERIDprkluE');

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

    return await response.stream.toBytes();
  }

  Future<Map<String, String>> _askQuestions() async {
    Map<String, String> answers = new Map();

    bool end = false;

    await _play('Please answer each question after it is asked. Valid commands are: repeat, skip, back, stop.');

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

      await _play(prompt);

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
            String value = element['value'];
            String type = element['type'];
            if (type != 'punct') output = output + ' ' + value;
          }

          debugPrint(output);
          if (!c.isCompleted) {
            c.complete(output);
          }
        }
      });

      String answer = '';
      String output = (await c.future).trim().toLowerCase();

      switch (output) {
        case 'skip':
          break;
        case '<unk>':
        case '':
        case 'repeat':
          i -= 1;
          break;
        case 'back':
          do {
            i -= 1;
          } while (i > 1 && questions[i].type == 'SECTION');
          i -= 1;
          break;
        case 'stop':
          end = true;
          break;
        default:
          if (question.type == 'CHECKBOX' && output != 'yes' && output != 'no') {
            i -= 1;
          }
          answer = output;
      }

      answers.update(question.id, (old) {
        return answer;
      }, ifAbsent: () {
        return answer;
      });
    }

    return answers;
  }

  Future<Uint8List> _submitAnswers() async {
    var request = new http.MultipartRequest(
        'POST', Uri.parse('http://d0e81c45.ngrok.io/process'));
    request.fields.addAll(answers);
    request.files.add(MultipartFile.fromBytes(
      'file',
      imageBytes,
    ));

    final response = await request.send();
    return await response.stream.toBytes();
  }

  void _choose() async {
    File image = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    Uint8List imageBytes = await _perspectiveImage(image);

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

    imageBytes = await _submitAnswers();

    setState(() {
      this.imageBytes = imageBytes;
    });
  }

  void _download() {

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
        body:
//      Padding(
//      padding: const EdgeInsets.all(20.0),
//      child: Row(
//      mainAxisAlignment: MainAxisAlignment.center,
//      crossAxisAlignment: CrossAxisAlignment.center,
//      children: <Widget>[
//      Column(
//      mainAxisAlignment: MainAxisAlignment.center,
//      crossAxisAlignment: CrossAxisAlignment.center,
//      children: <Widget>[
//      Text('Upload with ease - Click below',
//          style: TextStyle(
//          color: Colors.blueAccent,
//          fontWeight: FontWeight.w700,
//          fontSize: 28.0))
//      ],
//      ),

      Padding(
          padding: const EdgeInsets.all(30.0),

//    child: Row(
//      mainAxisAlignment: MainAxisAlignment.center,
//      crossAxisAlignment: CrossAxisAlignment.center,
//      children: <Widget>[
//      Column(
//      mainAxisAlignment: MainAxisAlignment.center,
//      crossAxisAlignment: CrossAxisAlignment.center,
//      children: <Widget>[
//      Text('Upload with ease - Click below',
//          style: TextStyle(
//          color: Colors.blueAccent,
//          fontWeight: FontWeight.w700,
//          fontSize: 28.0))
//      ],
//      ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[

                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    new Container(
                      margin: const EdgeInsets.only(top: 50),
                      child: Text("      Welcome to Comodium!   ",
                      style: TextStyle(
                        color: Colors.pinkAccent[400],
                        fontWeight: FontWeight.w700,
                        fontSize: 25.0,
                      ),
                    ),)

                  ],
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text("            Upload with ease",
                      style: TextStyle(
                        color: Colors.pinkAccent[400],
                        fontWeight: FontWeight.w700,
                        fontSize: 25.0,
                      ),
                    ),
                  ],
                ),

                new Container(
                  margin: const EdgeInsets.only(top: 60),
                  child: Material(
                  color: Colors.tealAccent,
                  borderRadius: BorderRadius.circular(24.0),
                  child: new FlatButton(

                      onPressed: () async {
                  await _play('Co-modium is the latin word for');
                  await _play('with ease');
                  await _play('click the yellow button to upload your file');
                },
                child: Center(
                    child: Padding(
                    padding: EdgeInsets.all(30.0),
                        child: Icon(
                        Icons.info, color: Colors.white,
                        size: 30.0),
                    )
                )
              )
                  )
          ),
                new Container(
                    margin: const EdgeInsets.only(top: 60),
                    child: Material(
                    color: Colors.amberAccent,
                    borderRadius: BorderRadius.circular(24.0),
                    child: new FlatButton(

                        onPressed: _choose,
                        child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(30.0),
                                  child: Icon(
                                      Icons.file_upload, color: Colors.white,
                                      size: 30.0),
                                )
                            )
                        )
                    )
                ),
                new Container(
                    margin: const EdgeInsets.only(top: 25),
                  child: imageBytes == null ? new Text('                                  No Image Selected')
                        : new FlatButton(
                      onPressed: _download,
                      child: Image.memory(imageBytes),
                    )
                  //child: new Text(imageBytes == null ? ('                                  No Image Selected') : '')
                    //imageBytes == null ? Text('                                  No Image Selected')
//                        : new FlatButton(
//                      onPressed: _download,
//                      child: Image.memory(imageBytes),
//                    )
                ),

              ]
          ),
        ),


    );
  }
}
