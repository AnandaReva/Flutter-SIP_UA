import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:magang_teleakses/utils/globalVar.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  Logger.level = Level.info;
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SIPClientProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magang',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class SIPClientProvider with ChangeNotifier {
  final SIPUAHelper _sipUAHelper = SIPUAHelper();
  bool isDialing = false;
  Call? currentCall;
  final Logger _logger = Logger();
  final GlobalVar _globalVar = GlobalVar.instance;

  SIPClientProvider() {
    _initializeSIP();
  }

  void startDialing() {
    isDialing = true;
    notifyListeners();
  }

  void endDialing() {
    isDialing = false;
    notifyListeners();
  }

  void _initializeSIP() async {
    _logger.i(" LOGGERTHIS: Initializing SIP...");
    try {
      UaSettings uaSettings = UaSettings();

/*       uaSettings.webSocketUrl = 'wss://zada-acd.servobot.ai/wsproxy';
      uaSettings.uri = 'sip:00003@zada-acd.servobot.ai';
      uaSettings.authorizationUser = 'customer';
      uaSettings.password = '1234';
      uaSettings.displayName = 'Customer';
      uaSettings.userAgent = 'Flutter SIP Client';
      uaSettings.transportType = TransportType.WS; */

      uaSettings.webSocketUrl = 'wss://winter.cayangqu.com/ws';
      uaSettings.uri = 'sip:magang@winter.cayangqu.com';
      uaSettings.authorizationUser = 'magang';
      uaSettings.password = '1234';
      uaSettings.displayName = 'Magang';
      uaSettings.userAgent = 'Flutter SIP Client';
      uaSettings.transportType = TransportType.WS;

      _logger.i(" LOGGERTHIS: Using URI: ${uaSettings.uri}");
      _logger.i(
          " LOGGERTHIS: Using authorizationUser: ${uaSettings.authorizationUser}");
      await _sipUAHelper.start(uaSettings);
      _sipUAHelper.addSipUaHelperListener(MySIPListener(this));

      _globalVar.errorMessageGlobal = "";
      _globalVar.statusMessageGlobal = "Disconnected";
      notifyListeners();

      _logger.i(" LOGGERTHIS: SIP initialized successfully");
    } catch (e) {
      _logger.e("LOGGERTHIS: Error initializing SIP: $e");
      setErrorMessage("Error initializing SIP: $e");
    }
  }

  void updateStatus(String message) {
    _globalVar.statusMessageGlobal = message;
    notifyListeners();
  }

  void setErrorMessage(String message) {
    _globalVar.errorMessageGlobal = message;
    notifyListeners();
  }

  SIPUAHelper get sipUAHelper => _sipUAHelper;
}

class MySIPListener extends SipUaHelperListener {
  final SIPClientProvider provider;
  final Logger _logger = Logger();

  MySIPListener(this.provider);

  @override
  void registrationStateChanged(RegistrationState state) {
    String message;
    switch (state.state) {
      case RegistrationStateEnum.REGISTERED:
        message = "Registered with SIP server ${state.cause}";
        _logger.i(" LOGGERTHIS: $message");
        break;
      case RegistrationStateEnum.UNREGISTERED:
        message = "Unregistered from SIP server ${state.cause}";
        _logger.i(" LOGGERTHIS: $message");
        break;
      case RegistrationStateEnum.NONE:
      case RegistrationStateEnum.REGISTRATION_FAILED:
        message = "Registration failed: ${state.cause}";
        _logger.i(" LOGGERTHIS: $message");
        break;
      default:
        message = "Unknown registration state, ${state.cause}";
        _logger.i(" LOGGERTHIS: $message");
    }
    provider.setErrorMessage(message);
  }

/*   @override
  void callStateChanged(Call call, CallState state) {
    provider.currentCall = call; // Update `currentCall`

    String message;

    _logger.i(
        "LOGGERTHIS: Current Call: ${provider.currentCall?.toString() ?? "null"}");

    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  initiating...");
        message = "Initiating Call...";
        break;
      case CallStateEnum.CONNECTING:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  connecting...");
        message = "Connecting...";
        break;
      case CallStateEnum.PROGRESS:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  in progress...");
        message = "In Progress...";
        if (provider.currentCall == null) {
          _logger.e(
              "LOGGERTHIS: Warning! currentCall is null during PROGRESS state!");
        }
        break;
      case CallStateEnum.ACCEPTED:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  accepted");
        message = "Call Accepted...";
        break;
      case CallStateEnum.CONFIRMED:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  confirmed");
        message = "Call Confirmed...";
        break;
      case CallStateEnum.ENDED:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  ended");
        message = "Call Ended";
        provider.endDialing();
        provider.currentCall =  null; // Hapus `currentCall` jika panggilan berakhir
        break;
      case CallStateEnum.FAILED:
        _logger.e("LOGGERTHIS: Call CallStateEnum  failed: ${state.cause}");
        message = "Call Failed: ${state.cause}";
        provider.endDialing();
        provider.currentCall = null; // Hapus `currentCall` jika panggilan gagal
        break;
      case CallStateEnum.STREAM:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  stream updated");
        message = "Stream Updated";
        break;
      case CallStateEnum.UNMUTED:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  unmuted");
        message = "Call Unmuted";
        break;
      case CallStateEnum.MUTED:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  muted");
        message = "Call Muted";
        break;
      case CallStateEnum.HOLD:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  on hold");
        message = "Call on Hold";
        break;
      case CallStateEnum.UNHOLD:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  resumed");
        message = "Call Resumed";
        break;
      case CallStateEnum.REFER:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  transfer initiated");
        message = "Call Transfer Initiated";
        break;
      case CallStateEnum.NONE:
        _logger.i(" LOGGERTHIS: No active call state");
        message = "No Active Call State";
        break;
      default:
        _logger.i(" LOGGERTHIS: Unknown Call State: ${state.state}");
        message = "Unknown Call State";
        break;
    }

    provider.updateStatus(message); // Update status dalam provider
  }
 */

  @override
  Future<void> callStateChanged(Call call, CallState state) async {
    String message;

    _logger.i("LOGGERTHIS: Current Call: ${call}");

    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  initiating...");
        message = "Initiating Call...";
        break;
      case CallStateEnum.CONNECTING:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  connecting...");
        message = "Connecting...";
        break;
      case CallStateEnum.PROGRESS:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  in progress...");
        message = "In Progress...";
        if (call == null) {
          _logger.e(
              "LOGGERTHIS: Warning! currentCall is null during PROGRESS state!");
        } else {
          try {
            // Minta izin dan dapatkan media stream untuk mikrofon
            MediaStream mediaStream =
                await navigator.mediaDevices.getUserMedia({
              'audio': true, // Aktifkan mikrofon
              'video': false // Nonaktifkan video
            });

            // Opsi untuk menjawab panggilan
            Map<String, dynamic> options = {
              'mediaConstraints': {'audio': true, 'video': false}
            };

            // Jawab panggilan dengan media stream
            call.answer(options, mediaStream: mediaStream);
            _logger.i("LOGGERTHIS: Call answered with microphone");
          } catch (e) {
            _logger.e("LOGGERTHIS: Error accessing microphone: $e");
            // Handle error - mungkin tampilkan pesan error ke pengguna
          }
        }
        break;
      case CallStateEnum.ACCEPTED:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  accepted");
        message = "Call Accepted...";
        break;
      case CallStateEnum.CONFIRMED:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  confirmed");
        message = "Call Confirmed...";
        break;
      case CallStateEnum.ENDED:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  ended");
        message = "Call Ended";
        provider.endDialing();
        provider.currentCall =
            null; // Hapus `currentCall` jika panggilan berakhir
        break;
      case CallStateEnum.FAILED:
        _logger.e("LOGGERTHIS: Call CallStateEnum  failed: ${state.cause}");
        message = "Call Failed: ${state.cause}";
        provider.endDialing();
        provider.currentCall = null; // Hapus `currentCall` jika panggilan gagal
        break;
      case CallStateEnum.STREAM:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  stream updated");
        message = "Stream Updated";
        break;
      case CallStateEnum.UNMUTED:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  unmuted");
        message = "Call Unmuted";
        break;
      case CallStateEnum.MUTED:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  muted");
        message = "Call Muted";
        break;
      case CallStateEnum.HOLD:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  on hold");
        message = "Call on Hold";
        break;
      case CallStateEnum.UNHOLD:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  resumed");
        message = "Call Resumed";
        break;
      case CallStateEnum.REFER:
        _logger.i(" LOGGERTHIS: Call CallStateEnum  transfer initiated");
        message = "Call Transfer Initiated";
        break;
      case CallStateEnum.NONE:
        _logger.i(" LOGGERTHIS: No active call state");
        message = "No Active Call State";
        break;
      default:
        _logger.i(" LOGGERTHIS: Unknown Call State: ${state.state}");
        message = "Unknown Call State";
        break;
    }

    provider.updateStatus(message); // Update status dalam provider
  }

  @override
  void transportStateChanged(TransportState state) {
    _logger.i(" LOGGERTHIS: Transport state: ${state.state}");
    if (state.state == TransportStateEnum.DISCONNECTED) {
      provider.updateStatus("Transport Disconnected");
    } else if (state.state == TransportStateEnum.CONNECTED) {
      provider.updateStatus("Transport Connected");
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    _logger.i(" LOGGERTHIS: LOGGERTHIS New Message received: $msg");
  }

  @override
  void onNewNotify(Notify ntf) {
    _logger.i(" LOGGERTHIS: LOGGERTHIS New notification received: $ntf");
  }

  @override
  void onNewReinvite(ReInvite event) {
    _logger.i(" LOGGERTHIS: LOGGERTHIS Received a re-invite request $event");
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Logger _logger = Logger();
  SIPUAHelper? _sipHelper;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  MediaStream? _localStream;
  final GlobalVar _globalVar = GlobalVar.instance;
  final TextEditingController _uriController = TextEditingController();

  bool _isMicMuted = false;
  bool _isCameraActive = false;

  Offset _localVideoOffset = const Offset(260.0, 600.0);

  @override
  void initState() {
    super.initState();
    _sipHelper =
        Provider.of<SIPClientProvider>(context, listen: false).sipUAHelper;
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();
  }

  @override
  void dispose() {
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    _localStream?.dispose();
    _uriController.dispose();
    super.dispose();
  }

  void _toggleMic() {
    setState(() {
      _isMicMuted = !_isMicMuted;
    });
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled =
            !_isMicMuted; // Mengaktifkan atau menonaktifkan mikrofon
      });
    }
    _logger
        .i(" LOGGERTHIS: Microphone is ${_isMicMuted ? 'muted' : 'unmuted'}");
  }

  // Fungsi untuk mengubah status video
  void _toggleCamera() {
    setState(() {
      _isCameraActive = !_isCameraActive;
    });
    if (_localStream != null) {
      _localStream!.getVideoTracks().forEach((track) {
        track.enabled =
            !_isCameraActive; // Mengaktifkan atau menonaktifkan Kamera
      });
    }
    _logger.i(" LOGGERTHIS: Video is ${_isCameraActive ? 'off' : 'on'}");
  }

  Future<void> _makeCall() async {
    _logger.i(" LOGGERTHIS: Executing _makeCall");
    _globalVar.errorMessageGlobal = "";

    final provider = Provider.of<SIPClientProvider>(context, listen: false);
    provider.startDialing();
    _logger.i(" LOGGERTHIS: Prepare Dialing");

    // Get the target URI from the text input
    final targetURI = _globalVar.targetURI;
    if (targetURI.isEmpty) {
      _logger.e("LOGGERTHIS: Target URI is empty");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter a valid target URI")),
      );
      return;
    }

    _logger.i(
        "LOGGERTHIS: Current Call: ${provider.currentCall?.toString() ?? "null"}");

    final mediaConstraints = <String, dynamic>{
      "audio": true,
      "video": {
        "mandatory": {
          "minWidth": "640",
          "minHeight": "480",
          "minFrameRate": "30"
        },
        "facingMode": "user"
      },
    };

    try {
      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      setState(() {
        _localRenderer?.srcObject = _localStream;
      });

      _logger.i("LOGGERTHIS: Making call to $targetURI");
      await _sipHelper?.call(targetURI, mediaStream: _localStream);
      _logger.i("LOGGERTHIS: Dialing...");
    } catch (e) {
      _logger.e("LOGGERTHIS: Error accessing media devices: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to access media devices")));
    }
  }

  Future<void> _answerCall() async {
    final currentCall =
        Provider.of<SIPClientProvider>(context, listen: false).currentCall;

    // final provider = Provider.of<SIPClientProvider>(context, listen: false);

    if (currentCall != null && currentCall.state == CallStateEnum.PROGRESS) {
      try {
        final mediaConstraints = <String, dynamic>{
          "audio": true,
          "video": true,
        };
        _localStream =
            await navigator.mediaDevices.getUserMedia(mediaConstraints);
        setState(() {
          _localRenderer?.srcObject = _localStream;
        });

        final callOptions = _sipHelper!.buildCallOptions(true)
          ..['mediaStream'] = _localStream;
        currentCall.answer(callOptions);
        _logger.i("LOGGERTHIS: Answering call...");
      } catch (e) {
        _logger.e("LOGGERTHIS: Error answering call: $e");
      }
    } else {
      _logger.w("LOGGERTHIS: No incoming call to answer");
    }
  }

  void _endCall() {
    final currentCall =
        Provider.of<SIPClientProvider>(context, listen: false).currentCall;
    if (currentCall != null) {
      currentCall.hangup();

      setState(() {
        _localRenderer?.srcObject = null;
        _remoteRenderer?.srcObject = null;
        _localStream?.dispose();
        _localStream = null;
      });
    } else {
      _logger.w("LOGGERTHIS: No active call to end");
    }
  }

  void _cancelDialing() {
    final provider = Provider.of<SIPClientProvider>(context, listen: false);
    provider.endDialing();
    _logger.i("LOGGERTHIS: Cancel dialing pressed");

    provider.setErrorMessage("DIALING CANCELLED");

    final currentCall = provider.currentCall;
    if (currentCall != null) {
      _logger.i("LOGGERTHIS: Hanging up current call");
      currentCall.hangup();
      setState(() {
        _localRenderer?.srcObject = null;
        _remoteRenderer?.srcObject = null;
        _localStream?.dispose();
        _localStream = null;
      });
    } else {
      _logger.w("LOGGERTHIS: No active call to hang up");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SIPClientProvider>(
      builder: (context, provider, child) {
        //   bool isCallActive = provider.currentCall != null && provider.isDialing;

        bool isCallActive = provider.currentCall != null; // Updated condition

        return Scaffold(
          body: Stack(
            children: [
              // Main content with video views
              Column(
                children: [
                  const Text(
                    "Version: 1.5",
                    style: TextStyle(color: Colors.black),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              border: Border.all(),
                              borderRadius: BorderRadius.circular(8.0),
                              color: Colors.black54,
                            ),
                            child: RTCVideoView(_remoteRenderer!),
                          ),
                        ),
                        Positioned(
                          left: _localVideoOffset.dx,
                          top: _localVideoOffset.dy,
                          child: Draggable(
                            feedback: Container(
                              width: 120,
                              height: 160,
                              decoration: BoxDecoration(
                                border: Border.all(),
                                borderRadius: BorderRadius.circular(8.0),
                                color: Colors.black54,
                              ),
                              child: RTCVideoView(_localRenderer!),
                            ),
                            childWhenDragging:
                                Container(), // Empty space when dragging
                            onDragStarted: () {
                              setState(() {});
                            },

                            onDragEnd: (details) {
                              setState(() {
                                // Ambil offset tanpa pengurangan
                                double newX = details.offset.dx;
                                double newY = details.offset.dy;

                                // Dapatkan dimensi layar
                                double screenWidth =
                                    MediaQuery.of(context).size.width;
                                double screenHeight =
                                    MediaQuery.of(context).size.height;

                                // Hitung batas
                                newX = newX.clamp(
                                    0.0,
                                    screenWidth -
                                        120); // 120 adalah lebar video lokal
                                newY = newY.clamp(
                                    0.0,
                                    screenHeight -
                                        160); // 160 adalah tinggi video lokal

                                _localVideoOffset = Offset(newX, newY);
                              });
                            },

                            child: Container(
                              width: 120,
                              height: 160,
                              decoration: BoxDecoration(
                                border: Border.all(),
                                borderRadius: BorderRadius.circular(8.0),
                                color: Colors.black54,
                              ),
                              child: RTCVideoView(_localRenderer!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Error and status messages overlay

              if (_globalVar.errorMessageGlobal.isNotEmpty)
                Positioned(
                  top: 90,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.red,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                          _globalVar.errorMessageGlobal,
                          style: const TextStyle(color: Colors.white),
                        )),
                      ],
                    ),
                  ),
                ),
              if (_globalVar.statusMessageGlobal.isNotEmpty)
                Positioned(
                  top:
                      40, // Adjust as needed to avoid overlap with error message
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.blue,
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                          _globalVar.statusMessageGlobal,
                          style: const TextStyle(color: Colors.white),
                        )),
                      ],
                    ),
                  ),
                ),

              Positioned(
                top: 140,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: TextFormField(
                    controller: _uriController,
                    decoration: const InputDecoration(
                      labelText:
                          "Target URI", // Tetap ditampilkan sebagai label
                      hintText:
                          "e.g., sip:target@zada-acd.servobot.ai", // Sebagai placeholder
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _globalVar.targetURI = value; // Update targetURI
                      setState(
                          () {}); // Rebuild to reflect the enabled/disabled state of the button
                    },
                  ),
                ),
              ),

              // Call control buttons at the bottom

              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _globalVar.targetURI.isNotEmpty &&
                                !provider.isDialing
                            ? _makeCall
                            : null, // Disable if targetURI is empty
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Dial"),
                      ),
                      /*      ElevatedButton(
                        onPressed: _answerCall, // Panggilan selalu aktif
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Answer"),
                      ), */

                      ElevatedButton(
                        onPressed: Provider.of<SIPClientProvider>(context,
                                        listen: true)
                                    .currentCall
                                    ?.state ==
                                CallStateEnum.PROGRESS
                            ? _answerCall
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Answer"),
                      ),
                      provider.isDialing
                          ? ElevatedButton(
                              onPressed: _cancelDialing,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Cancel Dialing"),
                            )
                          : ElevatedButton(
                              onPressed: isCallActive ? _endCall : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("End Call"),
                            ),
                    ],
                  ),
                ),
              ),

              Positioned(
                bottom: 90,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        width: 50, // Diameter of the circle
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Colors.white, // Background color
                          shape: BoxShape.circle, // Make it circular
                        ),
                        child: IconButton(
                          onPressed: _toggleMic,
                          icon: Icon(_isMicMuted ? Icons.mic_off : Icons.mic),
                          color: _isMicMuted ? Colors.red : Colors.green,
                        ),
                      ),
                      Container(
                        width: 50, // Diameter of the circle
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Colors.white, // Background color
                          shape: BoxShape.circle, // Make it circular
                        ),
                        child: IconButton(
                          onPressed: _toggleCamera,
                          icon: Icon(_isCameraActive
                              ? Icons.videocam_off
                              : Icons.videocam),
                          color: _isCameraActive ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
