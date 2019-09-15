import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:web_socket_channel/io.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mic_stream/mic_stream.dart';
import 'dart:async';


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final title = 'Cumotium';
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
            Text('     Hello! Upload with ease.', style: TextStyle(
          color: Colors.blueAccent,
          fontWeight: FontWeight.w700,
          fontSize: 28.0),
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
            new Material(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(24.0),
                child: Center(
                    child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Icon(Icons.file_upload,
                color: Colors.white, size: 30.0)
            ),

    )
              )]
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendMessage,
        tooltip: 'Send message',
        child: Icon(Icons.send),// This trailing comma makes auto-formatting nicer for build methods.
    ));
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










