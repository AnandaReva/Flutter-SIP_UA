import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
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
      home: const HomePage(title: 'Home Page'),
    );
  }
}

class SIPClientProvider with ChangeNotifier {
  final SIPUAHelper _sipUAHelper = SIPUAHelper();
  Call? currentCall;
  String errorMessage = "";
  String statusMessage = "Disconnected";

  SIPClientProvider() {
    _initializeSIP();
  }

  void _initializeSIP() async {
    try {
      UaSettings uaSettings = UaSettings()
        ..webSocketUrl = "wss://zada-acd.servobot.ai/wsproxy"
        ..password = "1234"
        ..authorizationUser = "customer"
        ..userAgent = "customer"
        ..transportType = TransportType.WS
        ..webSocketSettings.allowBadCertificate = true
        ..uri = "sip:customer@zada-acd.servobot.ai"
        ..displayName = "customer";

      await _sipUAHelper.start(uaSettings);
      _sipUAHelper.addSipUaHelperListener(MySIPListener(this));

      statusMessage = "Connected to SIP server";
      notifyListeners();
    } catch (e) {
      errorMessage = "Error initializing SIP: $e";
      notifyListeners();
    }
  }

  void updateStatus(String message) {
    statusMessage = message;
    notifyListeners();
  }

  void updateError(String message) {
    errorMessage = message;
    notifyListeners();
  }

  SIPUAHelper get sipUAHelper => _sipUAHelper;
}

class MySIPListener extends SipUaHelperListener {
  final SIPClientProvider provider;

  MySIPListener(this.provider);

  @override
  void registrationStateChanged(RegistrationState state) {
    if (state.state == RegistrationStateEnum.REGISTERED) {
      provider.updateStatus("Registered with SIP server");
    } else if (state.state == RegistrationStateEnum.UNREGISTERED) {
      provider.updateStatus("Unregistered from SIP server");
    } else if (state.state == RegistrationStateEnum.NONE) {
      provider.updateStatus("Registration failed: ${state.cause}");
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {
    provider.currentCall = call;

    switch (state.state) {
      case CallStateEnum.CONNECTING:
        provider.updateStatus("Connecting...");
        break;
      case CallStateEnum.PROGRESS:
        provider.updateStatus("In Progress...");
        break;
      case CallStateEnum.ACCEPTED:
        provider.updateStatus("Call Accepted");
        break;
      case CallStateEnum.CONFIRMED:
        provider.updateStatus("Call Confirmed");
        break;
      case CallStateEnum.ENDED:
        provider.updateStatus("Call Ended");
        provider.currentCall = null;
        break;
      default:
        break;
    }
  }
  
  @override
  void onNewMessage(SIPMessageRequest msg) {
    print("New Message received: $msg");
  }
  
  @override
  void onNewNotify(Notify ntf) {
    print("New notification received: $ntf");
  }

  @override
  void onNewReinvite(ReInvite event) {
  print("Received a re-invite request");
  }


  @override
  void transportStateChanged(TransportState state) {
    print("DEBUG Transport state: ${state.state}");
  
    if (state.state == TransportStateEnum.DISCONNECTED) {
      print("DEBUG Transport connection closed.");
    } else if (state.state == TransportStateEnum.CONNECTED) {
      print("DEBUG Transport connected to the server.");
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  SIPUAHelper? _sipHelper;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;

  @override
  void initState() {
    super.initState();
    _sipHelper = Provider.of<SIPClientProvider>(context, listen: false).sipUAHelper;
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    super.dispose();
  }

  Future<void> _makeCall() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        "audio": true,
        "video": {"facingMode": "user"}
      });

      setState(() {
        _localRenderer.srcObject = _localStream;
      });

      await _sipHelper?.call('sip:target@zada-acd.servobot.ai', mediaStream: _localStream);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to access media devices")),
      );
    }
  }

  Future<void> _answerCall() async {
    final currentCall = Provider.of<SIPClientProvider>(context, listen: false).currentCall;
    if (currentCall != null) {
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          "audio": true,
          "video": true
        });

        setState(() {
          _localRenderer.srcObject = _localStream;
        });

        final callOptions = _sipHelper!.buildCallOptions(true)..['mediaStream'] = _localStream;
        currentCall.answer(callOptions);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error answering call")),
        );
      }
    }
  }

  void _endCall() {
    final currentCall = Provider.of<SIPClientProvider>(context, listen: false).currentCall;
    if (currentCall != null) {
      currentCall.hangup();
      setState(() {
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
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
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    provider.statusMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (provider.errorMessage.isNotEmpty)
                Container(
                  color: Colors.red,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(provider.errorMessage, style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(border: Border.all()),
                        child: RTCVideoView(_localRenderer),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(border: Border.all()),
                        child: RTCVideoView(_remoteRenderer),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(onPressed: _makeCall, child: const Text("Dial")),
                    ElevatedButton(onPressed: _answerCall, child: const Text("Answer")),
                    ElevatedButton(
                      onPressed: _endCall,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Hang Up"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
