import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '宝宝在线',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BbzxPage(title: '视频在线'),
    );
  }
}

class BbzxPage extends StatefulWidget {
  const BbzxPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<BbzxPage> createState() => _BbzxPageState();
}

class _BbzxPageState extends State<BbzxPage> {
  List<dynamic> _cameras = [];
  String _url = 'Init...';
  int _curIndex = -1;
  late VlcPlayerController _controller;

  @override
  void initState() {
    String str;
    getData().then((resp) {
      String str = utf8.decode(resp.bodyBytes);
      Map<String, dynamic> guids = JsonCodec().decode(str);
      print(guids);
      setState(() {
        _cameras = guids['Guids'];
        _initController();
      });
    }).catchError((err) {
      setState(() {
        _url = err.toString();
      });
    });
    super.initState();
  }

  _initController() {
    _controller = VlcPlayerController.network(
      _url,
      hwAcc: HwAcc.FULL,
      // autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(2000),
        ]),
        http: VlcHttpOptions([
          VlcHttpOptions.httpReconnect(true),
        ]),
        rtp: VlcRtpOptions([
          VlcRtpOptions.rtpOverRtsp(true),
        ]),
      ),
    );
    _controller.addOnInitListener(() async {
      await _controller.startRendererScanning();
    });
    _controller.addOnRendererEventListener((type, id, name) {
      print('OnRendererEventListener $type $id $name');
    });
  }

  Widget _buildList() {
    final List<int> colorCodes = <int>[200, 100];
    return ListView.builder(
      padding: const EdgeInsets.all(6.0),
      itemCount: _cameras.length,
      itemBuilder: (context, i) {
        Map<String, dynamic> guid = _cameras[i];
        return Container(
          color: Colors.blue[colorCodes[i % 2]],
          child: ListTile(
            title: Text(
              guid["Name"],
              style: _curIndex == i ? TextStyle(color: Colors.red) : TextStyle(),
            ),
            onTap: () async {
              if (_curIndex == i) return;

              _curIndex = i;
              var resp = await getUrl(guid['Guid']);
              String str = utf8.decode(resp.bodyBytes);
              Map<String, dynamic> url = JsonCodec().decode(str);
              print(url);
              _url = url['Url'];
              await _controller.setMediaFromNetwork(
                _url,
                hwAcc: HwAcc.FULL,
              );
              setState(() {
                _url = _url;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildPlayer() {
    return VlcPlayer(
      controller: _controller,
      aspectRatio: 16 / 9,
      placeholder: const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: [
            Text(_url, maxLines: 1),
            Container(
              height: 340,
              child: _buildPlayer(),
            ),
            Expanded(
              child: _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() async {
    super.dispose();
    await _controller.stopRendererScanning();
    await _controller.dispose();
  }

  Future<Response> getData() async {
    const String authority = 'demo.dfc.cn:8081';
    const String path = '/list';
    Uri url = Uri.http(authority, path);
    Response resp = await http.get(url);
    return resp;
  }

  Future<Response> getUrl(String guid) async {
    const String authority = 'demo.dfc.cn:8081';
    const String path = '/url';
    Map<String, dynamic>? param = {'guid': guid};
    Uri url = Uri.http(authority, path, param);
    Response resp = await http.get(url);
    return resp;
  }

}
