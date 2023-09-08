import 'package:catcher/model/platform_type.dart';
import 'package:catcher/model/report.dart';
import 'package:catcher/model/report_handler.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:flutter/material.dart';

class ToastHandler extends ReportHandler {
  final StyledToastPosition position;
  final Color backgroundColor;
  final Color textColor;
  final double textSize;
  final String? customMessage;
  final bool handleWhenRejected;

  ToastHandler({
    this.position = StyledToastPosition.bottom,
    this.backgroundColor = Colors.black87,
    this.textColor = Colors.white,
    this.textSize = 12,
    this.customMessage,
    this.handleWhenRejected = false,
  });

  @override
  List<PlatformType> getSupportedPlatforms() => [
        PlatformType.android,
        PlatformType.iOS,
        PlatformType.web,
        PlatformType.linux,
        PlatformType.macOS,
        PlatformType.windows,
      ];

  @override
  Future<bool> handle(Report error, BuildContext? context) async {
    showToast(_getErrorMessage(error),
        backgroundColor: backgroundColor,
        textStyle: TextStyle(color: textColor, fontSize: textSize),
        position: position);

    return true;
  }

  String _getErrorMessage(Report error) {
    if (customMessage?.isNotEmpty == true) {
      return customMessage!;
    } else {
      return "${localizationOptions.toastHandlerDescription} ${error.error}";
    }
  }
}
