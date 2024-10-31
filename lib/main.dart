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
    _logger.i(" LOGGER: Initializing SIP...");
    try {
      UaSettings uaSettings = UaSettings()
        ..webSocketUrl = "wss://zada-acd.servobot.ai/wsproxy"
        ..password = "1234"
        ..authorizationUser = "customer"
        ..userAgent = "customer"
        ..transportType = TransportType.WS
        ..webSocketSettings.allowBadCertificate = true
        ..uri = "sip:customer@zada-acd.servobot.ai"
        ..displayName = "customer 1"
        ..register = false;

      await _sipUAHelper.start(uaSettings);
      _sipUAHelper.addSipUaHelperListener(MySIPListener(this));

      _globalVar.errorMessageGlobal = "";
      _globalVar.statusMessageGlobal = "Disconnected";
      notifyListeners();

      _logger.i(" LOGGER: SIP initialized successfully");
    } catch (e) {
      _logger.e("LOGGER: Error initializing SIP: $e");
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
        message = "Registered with SIP server";
        break;
      case RegistrationStateEnum.UNREGISTERED:
        message = "Unregistered from SIP server";
        break;
      case RegistrationStateEnum.NONE:
        message = "Registration failed: ${state.cause}";
        break;
      default:
        message = "Unknown registration state";
    }
    provider.setErrorMessage(message);
  }

  @override
  void callStateChanged(Call call, CallState state) {
    provider._globalVar.currentCall = call;

    String message;
    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        _logger.i(" LOGGER: Call initiating...");
        message = "Initiating Call...";
        break;
      case CallStateEnum.CONNECTING:
        _logger.i(" LOGGER: Call connecting...");
        message = "Connecting...";
        break;
      case CallStateEnum.PROGRESS:
        _logger.i(" LOGGER: Call in progress...");
        message = "In Progress...";
        break;
      case CallStateEnum.ACCEPTED:
        _logger.i(" LOGGER: Call accepted");
        message = "Call Accepted...";
        break;
      case CallStateEnum.CONFIRMED:
        _logger.i(" LOGGER: Call confirmed");
        message = "Call Confirmed...";
        break;
      case CallStateEnum.ENDED:
        _logger.i(" LOGGER: Call ended");
        message = "Call Ended";
        provider._globalVar.currentCall = null;
        break;
      case CallStateEnum.FAILED:
        _logger.e("LOGGER: Call failed: ${state.cause}");
        message = "Call Failed: ${state.cause}";
        provider.setErrorMessage(message);
        provider.endDialing();
        provider._globalVar.currentCall = null;
        return;
      case CallStateEnum.STREAM:
        _logger.i(" LOGGER: Call stream updated");
        message = "Stream Updated";
        break;
      case CallStateEnum.UNMUTED:
        _logger.i(" LOGGER: Call unmuted");
        message = "Call Unmuted";
        break;
      case CallStateEnum.MUTED:
        _logger.i(" LOGGER: Call muted");
        message = "Call Muted";
        break;
      case CallStateEnum.HOLD:
        _logger.i(" LOGGER: Call on hold");
        message = "Call on Hold";
        break;
      case CallStateEnum.UNHOLD:
        _logger.i(" LOGGER: Call resumed");
        message = "Call Resumed";
        break;
      case CallStateEnum.REFER:
        _logger.i(" LOGGER: Call transfer initiated");
        message = "Call Transfer Initiated";
        break;
      default:
        _logger.i(" LOGGER: Unknown Call State: ${state.state}");
        message = "Unknown Call State";
        break;
    }

    provider.updateStatus(message);
  }

  @override
  void transportStateChanged(TransportState state) {
    _logger.i(" LOGGER: Transport state: ${state.state}");
    if (state.state == TransportStateEnum.DISCONNECTED) {
      provider.updateStatus("Transport Disconnected");
    } else if (state.state == TransportStateEnum.CONNECTED) {
      provider.updateStatus("Transport Connected");
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    _logger.i(" LOGGER: LOGGER New Message received: $msg");
  }

  @override
  void onNewNotify(Notify ntf) {
    _logger.i(" LOGGER: LOGGER New notification received: $ntf");
  }

  @override
  void onNewReinvite(ReInvite event) {
    _logger.i(" LOGGER: LOGGER Received a re-invite request $event");
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

  Offset _localVideoOffset = Offset(16.0, 16.0); // Initial position
  bool _dragging = false;

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
    super.dispose();
  }

  Future<void> _makeCall() async {
    _logger.i(" LOGGER: Executing _makeCall");
    _globalVar.errorMessageGlobal = "";

    final provider = Provider.of<SIPClientProvider>(context, listen: false);
    provider.startDialing();

   // await provider.sipUAHelper.call('sip:target@zada-acd.servobot.ai');

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

      await _sipHelper?.call('sip:target@zada-acd.servobot.ai',
          mediaStream: _localStream);
      _logger.i(" LOGGER: Dialing...");


      
    } catch (e) {
      _logger.e("LOGGER: Error accessing media devices: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to access media devices")));
    }
  }

  Future<void> _answerCall() async {
    final currentCall =
        Provider.of<SIPClientProvider>(context, listen: false).currentCall;
    if (currentCall != null) {
      try {
        final mediaConstraints = <String, dynamic>{
          "audio": true,
          "video": true
        };
        _localStream =
            await navigator.mediaDevices.getUserMedia(mediaConstraints);
        setState(() {
          _localRenderer?.srcObject = _localStream;
        });

        final callOptions = _sipHelper!.buildCallOptions(true)
          ..['mediaStream'] = _localStream;
        currentCall.answer(callOptions);
        _logger.i(" LOGGER: Answering call...");
      } catch (e) {
        _logger.e("LOGGER: Error answering call: $e");
      }
    } else {
      _logger.w("LOGGER: No incoming call to answer");
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
      _logger.w("LOGGER: No active call to end");
    }
  }

  void _cancelDialing() {
    final provider = Provider.of<SIPClientProvider>(context, listen: false);
    provider.endDialing(); // Ends dialing state

    // If a call is in progress, hang it up
    final currentCall = provider.currentCall;
    if (currentCall != null) {
      currentCall.hangup();
      setState(() {
        _localRenderer?.srcObject = null;
        _remoteRenderer?.srcObject = null;
        _localStream?.dispose();
        _localStream = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SIPClientProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          body: Stack(
            children: [
              // Main content with video views
              Column(
                children: [
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
                              setState(() {
                                _dragging = true;
                              });
                            },

                            onDragEnd: (details) {
                              setState(() {
                                _dragging = false;

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
              // Call control buttons at the bottom

              if (provider.isDialing)
                Positioned(
                  bottom: 80,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: _cancelDialing,
                      child: const Text('Cancel Dialing'),
                    ),
                  ),
                ),

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
                        onPressed: provider.isDialing ? null : _makeCall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Dial"),
                      ),
                      ElevatedButton(
                        onPressed: provider.isDialing ? null : _answerCall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Answer"),
                      ),
                      ElevatedButton(
                        onPressed: provider.isDialing ? null : _endCall,
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
            ],
          ),
        );
      },
    );
  }
}
