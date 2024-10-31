import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';

class GlobalVar extends ChangeNotifier {
  static final GlobalVar _instance = GlobalVar._internal();
  factory GlobalVar() => _instance;
  GlobalVar._internal();

  Call? _currentCall; // Moved from SIPClientProvider
  String _errorMessageGlobal = ""; // Moved from SIPClientProvider
  String _statusMessageGlobal = ""; // Moved from SIPClientProvider


  Call? get currentCall => _currentCall;
  set currentCall(Call? call) {
    _currentCall = call;
    notifyListeners();
  }

  String get errorMessageGlobal => _errorMessageGlobal;
  set errorMessageGlobal(String value) {
    _errorMessageGlobal = value;
    notifyListeners();
  }

  String get statusMessageGlobal => _statusMessageGlobal;

  set statusMessageGlobal(String value) {
    _statusMessageGlobal = value;
    notifyListeners();
  }

  static GlobalVar get instance => _instance;
}