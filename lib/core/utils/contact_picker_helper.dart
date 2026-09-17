import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';

class ContactPickerHelper {
  /// Requests contact permission and opens native contact picker.
  /// Returns a record with extracted (name, phone) or null if cancelled / unsupported.
  static Future<({String name, String? phone})?> pickContact(BuildContext context) async {
    if (kIsWeb) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خاصية استيراد جهات الاتصال مدعومة فقط على أجهزة الهاتف المحمول'),
          ),
        );
      }
      return null;
    }

    try {
      final status = await Permission.contacts.request();

      if (status.isGranted) {
        final contact = await ContactsService.openDeviceContactPicker();
        if (contact == null) return null;

        String name = contact.displayName?.trim() ?? '';
        if (name.isEmpty) {
          final first = contact.givenName?.trim() ?? '';
          final last = contact.familyName?.trim() ?? '';
          name = '$first $last'.trim();
        }

        String? phone;
        if (contact.phones != null && contact.phones!.isNotEmpty) {
          final firstVal = contact.phones!.first.value?.trim();
          if (firstVal != null && firstVal.isNotEmpty) {
            phone = firstVal;
          }
        }

        return (name: name, phone: phone);
      } else if (status.isPermanentlyDenied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم رفض إذن الوصول لجهات الاتصال. يرجى تفعيله من إعدادات الهاتف.'),
              action: SnackBarAction(
                label: 'الإعدادات',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم منح إذن الوصول إلى جهات الاتصال'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ContactPickerHelper] Error picking contact: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء فتح جهات الاتصال: $e')),
        );
      }
    }

    return null;
  }
}
