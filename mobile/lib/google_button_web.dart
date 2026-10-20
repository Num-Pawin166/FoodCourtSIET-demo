import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// บนเว็บ Google บังคับให้ใช้ปุ่มที่ Google วาดเอง ผลลัพธ์มาทาง GoogleAuth.events
Widget buildGoogleWebButton() => web.renderButton(
      configuration: web.GSIButtonConfiguration(
        theme: web.GSIButtonTheme.outline,
        size: web.GSIButtonSize.large,
        text: web.GSIButtonText.signinWith,
        shape: web.GSIButtonShape.pill,
        minimumWidth: 300,
        locale: 'th',
      ),
    );
