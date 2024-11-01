

import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:logger/logger.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIP Messaging Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SIPMessageScreen(),
    );
  }
}

class SIPMessageScreen extends StatefulWidget {
  @override
  _SIPMessageScreenState createState() => _SIPMessageScreenState();
}

class _SIPMessageScreenState extends State<SIPMessageScreen> implements SipUaHelperListener {
  final SIPUAHelper _helper = SIPUAHelper();
  final Logger _logger = Logger(); // Inisialisasi logger

  String _status = "Connecting...";
  TextEditingController _messageController = TextEditingController();
  String _responseMessage = "";

  @override
  void initState() {
    super.initState();
    _initializeSIP();
    _helper.addSipUaHelperListener(this);
  }

  @override
  void dispose() {
    _helper.removeSipUaHelperListener(this);
    _messageController.dispose(); // Dispose the controller to free resources
    super.dispose();
  }

  // Fungsi untuk konfigurasi dan koneksi ke server SIP
  void _initializeSIP() {
    UaSettings settings = UaSettings();
    settings.webSocketUrl = 'wss://zada-acd.servobot.ai/wsproxy';
    settings.uri = 'sip:00003@zada-acd.servobot.ai';
    settings.authorizationUser = 'customer';
    settings.password = '1234';
    settings.displayName = 'Customer';
    settings.userAgent = 'Flutter SIP Client';
    settings.transportType = TransportType.WS;

    _logger.i("LOGGERTHIS Initializing SIP with settings: $settings");
    _helper.start(settings);
  }

  // Fungsi untuk mengirim pesan
  Future<void> _sendMessage() async {
    String target = 'sip:00003@zada-acd.servobot.ai';
    String message = _messageController.text;

    if (message.isNotEmpty) {
      try {
        _logger.i("LOGGERTHIS Sending message to $target: $message");
        await _helper.sendMessage(target, message);
        setState(() {
          _responseMessage = "Message sent: $message";
        });
        _logger.i("LOGGERTHIS Message sent successfully");
      } catch (error) {
        setState(() {
          _responseMessage = "Failed to send message: $error";
        });
        _logger.e("Failed to send message: $error");
      }
    }
  }

  // Fungsi ini dipanggil saat menerima pesan
  @override
  void onNewMessage(SIPMessageRequest msg) {
    if (msg.request.body != null) {
      _logger.i("LOGGERTHIS Received message: ${msg.request.body}");
      setState(() {
        _responseMessage = "Received message: ${msg.request.body}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SIP Messaging Demo'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _status,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: "Enter message",
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _sendMessage,
                child: Text("Send Message"),
              ),
              SizedBox(height: 20),
              Text(
                _responseMessage,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Implementasi listener lainnya
  void onRegistrationStateChanged(RegistrationState state) {
    _logger.i("LOGGERTHIS Registration state changed: ${state.state}");
    setState(() {
      _status = 'Registration state: ${state.state}';
    });
  }

  void onTransportStateChanged(TransportState state) {
    _logger.i("LOGGERTHIS Transport state changed: ${state.state}");
    setState(() {
      _status = 'Transport state: ${state.state}';
    });
  }

  @override
  void onNewNotify(Notify message) {
    _logger.i("LOGGERTHIS Received new notify: ${message}");
  }

  void onAcknowledgeReceived() {
    _logger.i("LOGGERTHIS Acknowledge received");
  }

  void onAcknowledgeSent() {
    _logger.i("LOGGERTHIS Acknowledge sent");
  }

  void onAcknowledgeFailure() {
    _logger.w("Acknowledge failed");
  }

  @override
  void callStateChanged(Call call, CallState state) {
    _logger.i("LOGGERTHIS Call state changed: ${state.state}");
  }

  @override
  void onNewReinvite(ReInvite event) {
    _logger.i("LOGGERTHIS Received new reinvite");
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    _logger.i("LOGGERTHIS Registration state changed (deprecated listener): ${state.state}");
  }

  @override
  void transportStateChanged(TransportState state) {
    _logger.i("LOGGERTHIS Transport state changed (deprecated listener): ${state.state}");
  }
}
