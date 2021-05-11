import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() => runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: WebRTCTesting(),
      ),
    );

class WebRTCTesting extends StatefulWidget {
  WebRTCTesting({Key? key}) : super(key: key);

  @override
  _WebRTCTestingState createState() => _WebRTCTestingState();
}

class _WebRTCTestingState extends State<WebRTCTesting> {
  bool _offer = false;
  TextEditingController _sdpCandidateTFController = TextEditingController();

  late MediaStream _localMediaStream;

  final RTCVideoRenderer _localVideoRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteVideoRenderer = RTCVideoRenderer();

  late RTCPeerConnection _peerConnection;

  @override
  void initState() {
    super.initState();
    initVideoRenderers();

    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      'iceServers': [
        {'url': "stun:stun.l.google.com:19302"},
      ],
    };

    final Map<String, dynamic> offerSDPConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
    };

    _localMediaStream = await _getUserMedia();

    RTCPeerConnection _pc =
        await createPeerConnection(configuration, offerSDPConstraints);

    _pc.addStream(_localMediaStream);

    _pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMLineIndex': e.sdpMlineIndex.toString(),
        }));
      }
    };

    _pc.onIceConnectionState = (e) {
      print(e);
    };

    _pc.onAddStream = (stream) {
      _remoteVideoRenderer.srcObject = stream;
      print("ADD STREAM: ${stream.id}");
    };

    return _pc;
  }

  void initVideoRenderers() async {
    await _localVideoRenderer.initialize();
    await _remoteVideoRenderer.initialize();
  }

  Future<MediaStream> _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': false,
      'video': {
        'facingMode': 'user',
      }
    };

    MediaStream _stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localVideoRenderer.srcObject = _stream;

    return _stream;
  }

  _createOffer() async {
    RTCSessionDescription _description =
        await _peerConnection.createOffer({'offerToReceiveVideo': 1});

    var session = parse(_description.sdp!);
    print(json.encode(session));
    _offer = true;
    _peerConnection.setLocalDescription(_description);
  }

  _createAnswer() async {
    RTCSessionDescription description =
        await _peerConnection.createAnswer({'offerToReceiveVideo': 1});

    var session = parse(description.sdp!);

    print(json.encode(session));
    _peerConnection.setLocalDescription(description);
  }

  _setCandidate() async {
    String jsonString = _sdpCandidateTFController.text;
    dynamic session = await jsonDecode("jsonString");

    print(session['candidate']);

    dynamic candidate = RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);

    await _peerConnection.addCandidate(candidate);
  }

  _setRemoteDescription() async {
    String jsonString = _sdpCandidateTFController.text;
    dynamic session = await jsonDecode('$jsonString');

    String _sdp = write(session, null);

    RTCSessionDescription _description =
        RTCSessionDescription(_sdp, _offer ? 'answer' : 'offer');

    print(_description.toMap());

    await _peerConnection.setRemoteDescription(_description);
  }

  Row offerAndAnswerButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: _createOffer,
            child: Text("Offer"),
          ),
          ElevatedButton(
            onPressed: _createAnswer,
            child: Text("Answer"),
          ),
        ],
      );

  SizedBox videoRenderers() => SizedBox(
        height: 210,
        child: Row(
          children: [
            Flexible(
              child: Container(
                color: Colors.black,
                margin: const EdgeInsets.all(5.0),
                child: RTCVideoView(_localVideoRenderer),
              ),
            ),
            Flexible(
              child: Container(
                color: Colors.black,
                margin: const EdgeInsets.all(5.0),
                child: RTCVideoView(_remoteVideoRenderer),
              ),
            ),
          ],
        ),
      );

  Padding sdpCandidateTF() => Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _sdpCandidateTFController,
          keyboardType: TextInputType.multiline,
          maxLines: 4,
          maxLength: TextField.noMaxLength,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("WebRTC"),
      ),
      body: Container(
        child: Column(
          children: [
            videoRenderers(),
            sdpCandidateTF(),
            offerAndAnswerButtons(),
            sdpCandidateButtons(),
          ],
        ),
      ),
    );
  }

  Row sdpCandidateButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: _setRemoteDescription,
            child: Text("Set Remote Desc.."),
          ),
          ElevatedButton(
            onPressed: _setCandidate,
            child: Text("Set Candidate.."),
          ),
        ],
      );

  @override
  void dispose() {
    super.dispose();
    _localVideoRenderer.dispose();
    _remoteVideoRenderer.dispose();
  }
}
