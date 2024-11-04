import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:logger/logger.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIP Dialer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DialScreen(),
    );
  }
}

class DialScreen extends StatefulWidget {
  @override
  _DialScreenState createState() => _DialScreenState();
}

class _DialScreenState extends State<DialScreen>
    implements SipUaHelperListener {
  late SIPUAHelper _sipHelper;
  late Logger _logger;

  @override
  void initState() {
    super.initState();
    _sipHelper = SIPUAHelper();
    _logger = Logger();

    _sipHelper.addSipUaHelperListener(this);
    _initializeSIP();
  }

  void _initializeSIP() {
    var settings = UaSettings();
    settings.transportType = TransportType.WS;
    settings.webSocketUrl = 'wss://zada-acd.servobot.ai/wsproxy';
    settings.uri = 'sip:00003@zada-acd.servobot.ai';
    settings.authorizationUser = 'customer';
    settings.password = '1234';
    settings.displayName = 'Customer Test Flutter';
    settings.userAgent = 'Flutter SIP UA';

    settings.dtmfMode = DtmfMode.RFC2833;
    settings.register = true;

    _sipHelper.start(settings);
  }

/*   void _makeCall() {
    const target = '';
    _sipHelper.call(
      target,
      customOptions: <String, dynamic>{
        'audio': true,
        'video': false,
      },
    );
    _logger.i(' LOGGERTHIS Initiating call to $target');
  } */

 void _sendMessage() {
  const target = 'sip:00003@zada-acd.servobot.ai;transport=ws'; // Ganti dengan target yang sesuai
  const messageBody = 'Hello, this is a test message!'; // Pesan yang akan dikirim

  try {
    _sipHelper.sendMessage(
      target,
      messageBody,
    );
    _logger.i(' LOGGERTHIS Sending message to $target: $messageBody');
  } catch (e) {
    // Tangani kesalahan yang mungkin terjadi
    _logger.e(' LOGGERTHIS Failed to send message: $e');
    // Anda dapat menambahkan logika tambahan di sini, seperti menampilkan dialog kesalahan
  }
}
  @override
  void registrationStateChanged(RegistrationState state) {
    _logger.i(' LOGGERTHIS Registration state changed: ${state.state}');
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
        message = "Registration NONE: ${state.cause}";
        _logger.w(" LOGGERTHIS: $message");
        break;
      case RegistrationStateEnum.REGISTRATION_FAILED:
        message = "Registration failed: ${state.cause}";
        _logger.e(" LOGGERTHIS: $message");
        break;
      default:
        message = "Unknown registration state, ${state.cause}";
        _logger.e(" LOGGERTHIS: $message");
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {
    _logger.i(' LOGGERTHIS Call state changed: ${state.state}');



    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        _logger.i(" LOGGERTHIS: Call initiating...");
        break;
      case CallStateEnum.CONNECTING:
        _logger.i(" LOGGERTHIS: Call connecting...");
        break;
      case CallStateEnum.PROGRESS:
        _logger.i(" LOGGERTHIS: Call in progress...");
        break;
      case CallStateEnum.ACCEPTED:
        _logger.i(" LOGGERTHIS: Call accepted");
        break;
      case CallStateEnum.CONFIRMED:
        _logger.i(" LOGGERTHIS: Call confirmed");
        break;
      case CallStateEnum.ENDED:
        _logger.i(" LOGGERTHIS: Call ended");
        break;
      case CallStateEnum.FAILED:
        _logger.e(" LOGGERTHIS: Call failed: ${state.cause}");
        // Log the cause directly
        _logger.e(
            " LOGGERTHIS: Call failure cause: ${state.cause?.toString() ?? "No cause provided"}");
        return; // Early return to prevent further processing
      case CallStateEnum.STREAM:
        _logger.i(" LOGGERTHIS: Call stream updated");
        break;
      case CallStateEnum.UNMUTED:
        _logger.i(" LOGGERTHIS: Call unmuted");
        break;
      case CallStateEnum.MUTED:
        _logger.i(" LOGGERTHIS: Call muted");
        break;
      case CallStateEnum.HOLD:
        _logger.i(" LOGGERTHIS: Call on hold");
        break;
      case CallStateEnum.UNHOLD:
        _logger.i(" LOGGERTHIS: Call resumed");
        break;
      case CallStateEnum.REFER:
        _logger.i(" LOGGERTHIS: Call transfer initiated");
        break;
      case CallStateEnum.NONE:
        _logger.i(" LOGGERTHIS: No active call state");
        break;
      default:
        _logger.i(" LOGGERTHIS: Unknown Call State: ${state.state}");
        break;
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    _logger.i(' LOGGERTHIS Transport state changed: ${state.state}');
  }

  @override
  void dispose() {
    _sipHelper.removeSipUaHelperListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SIP Dialer'),
      ),
      body: Center(
          child: Column(
        children: [
          ElevatedButton(
            onPressed: null, // _makeCall,
            child: Text('Dial 00003'),
          ),
          ElevatedButton(
            onPressed: _sendMessage, // Panggil fungsi untuk mengirim pesan
            child: Text('Send Message'),
          ),
        ],
      )),
    );
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    _logger.i("LOGGERTHIS: New message received: ${msg}");
  }

  @override
  void onNewNotify(Notify ntf) {
    _logger.i("LOGGERTHIS: New notification received: ${ntf}");
  }

  @override
  void onNewReinvite(ReInvite event) {
    _logger.i("LOGGERTHIS: New reinvite received. ${event}");
    // Tangani reinvite jika perlu, misalnya untuk mengubah stream media
  }
}
