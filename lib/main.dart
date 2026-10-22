import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

// خدمة تخزين محلية متطورة تدعم الويب وبرامج سطح المكتب (Windows EXE) لحفظ البيانات بصفة دائمة
class LocalStorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
    } catch (e) {
      print('Init error: $e');
    }
  }

  static const String _storageKey = 'xelo_work_manager_master_storage_v61';

  static Map<String, dynamic> loadAppData() {
    try {
      if (kIsWeb) {
        final rawData = html.window.localStorage[_storageKey];
        if (rawData == null || rawData.isEmpty) return {};
        return jsonDecode(rawData);
      } else {
        final rawData = _prefs?.getString(_storageKey);
        if (rawData == null || rawData.isEmpty) return {};
        return jsonDecode(rawData);
      }
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveAppData(Map<String, dynamic> data) async {
    try {
      if (kIsWeb) {
        html.window.localStorage[_storageKey] = jsonEncode(data);
      } else {
        await init();
        await _prefs?.setString(_storageKey, jsonEncode(data));
      }
    } catch (e) {
      print('Error saving: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await LocalStorageService.init();
  }
  runApp(const WorkManagerApp());
}

class WorkManagerApp extends StatefulWidget {
  const WorkManagerApp({super.key});

  @override
  State<WorkManagerApp> createState() => _WorkManagerAppState();
}

class _WorkManagerAppState extends State<WorkManagerApp> {
  bool _isArabic = true;

  void _toggleLanguage() {
    setState(() => _isArabic = !_isArabic);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _isArabic ? 'XELO Work Manager - إدارة العمل' : 'XELO Work Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: Colors.white70),
          titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          titleMedium: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          labelLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      home: MainNavigationScreen(
        isArabic: _isArabic,
        onToggleLanguage: _toggleLanguage,
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final bool isArabic;
  final VoidCallback onToggleLanguage;

  const MainNavigationScreen({
    super.key,
    required this.isArabic,
    required this.onToggleLanguage,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _isAdmin = true;
  String _adminUsername = 'admin';
  String _adminPassword = '123';
  String? _adminAvatarImage;

  String _searchTeam = '';
  String _searchTasks = '';
  String _searchParts = '';
  String _searchNotes = '';
  String _searchEvals = '';
  String _searchShifts = '';

  late List<Map<String, dynamic>> _teamMembers;
  late List<Map<String, dynamic>> _tasks;
  late List<Map<String, dynamic>> _spareParts;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  void _loadAllData() {
    final savedData = LocalStorageService.loadAppData();
    
    if (savedData.isNotEmpty) {
      try {
        _teamMembers = List<Map<String, dynamic>>.from(
          savedData['team']?.map((e) => Map<String, dynamic>.from(e)) ?? _defaultTeam
        );
        _tasks = List<Map<String, dynamic>>.from(
          savedData['tasks']?.map((e) => Map<String, dynamic>.from(e)) ?? _defaultTasks
        );
        _spareParts = List<Map<String, dynamic>>.from(
          savedData['parts']?.map((e) => Map<String, dynamic>.from(e)) ?? _defaultSpareParts
        );
        _adminUsername = savedData['adminUser'] ?? 'admin';
        _adminPassword = savedData['adminPass'] ?? '123';
        _adminAvatarImage = savedData['adminAvatar'];
      } catch (e) {
        _loadDefaults();
      }
    } else {
      _loadDefaults();
    }
  }

  void _loadDefaults() {
    _teamMembers = List.from(_defaultTeam);
    _tasks = List.from(_defaultTasks);
    _spareParts = List.from(_defaultSpareParts);
  }

  void _persistAllData() {
    try {
      final dataToSave = {
        'team': _teamMembers,
        'tasks': _tasks,
        'parts': _spareParts,
        'adminUser': _adminUsername,
        'adminPass': _adminPassword,
        'adminAvatar': _adminAvatarImage,
      };
      LocalStorageService.saveAppData(dataToSave);
    } catch (e) {
      print('Error saving: $e');
    }
  }

  Future<void> _pickImage(Function(String) onImageSelected) async {
    if (kIsWeb) {
      final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
      uploadInput.click();
      uploadInput.onChange.listen((e) {
        final files = uploadInput.files;
        if (files!.isEmpty) return;
        final reader = html.FileReader();
        reader.readAsDataUrl(files[0]);
        reader.onLoadEnd.listen((e) {
          onImageSelected(reader.result as String);
        });
      });
    } else {
      final file_selector.XTypeGroup typeGroup = file_selector.XTypeGroup(
        label: 'images',
        extensions: ['jpg', 'png', 'jpeg'],
      );
      final file_selector.XFile? file = await file_selector.openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        final bytes = await file.readAsBytes();
        onImageSelected('data:image/png;base64,${base64Encode(bytes)}');
      }
    }
  }

  void _exportData() {
    try {
      final dataToExport = {
        'team': _teamMembers,
        'tasks': _tasks,
        'parts': _spareParts,
        'adminUser': _adminUsername,
        'adminPass': _adminPassword,
        'adminAvatar': _adminAvatarImage,
      };
      final jsonString = jsonEncode(dataToExport);
      if (kIsWeb) {
        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'xelo_work_manager_backup_${DateTime.now().toString().split(' ')[0]}.json')
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isArabic ? 'تم تصدير النسخة الاحتياطية بنجاح' : 'Backup exported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isArabic ? 'فشل التصدير: $e' : 'Export failed: $e')),
      );
    }
  }

  void _importData() {
    if (kIsWeb) {
      final uploadInput = html.FileUploadInputElement()..accept = '.json';
      uploadInput.click();

      uploadInput.onChange.listen((e) {
        final files = uploadInput.files;
        if (files!.isEmpty) return;
        final reader = html.FileReader();
        reader.readAsText(files[0]);
        reader.onLoadEnd.listen((e) {
          try {
            final content = reader.result as String;
            final decodedData = jsonDecode(content) as Map<String, dynamic>;
            
            setState(() {
              if (decodedData.containsKey('team')) {
                _teamMembers = List<Map<String, dynamic>>.from(
                  decodedData['team'].map((e) => Map<String, dynamic>.from(e))
                );
              }
              if (decodedData.containsKey('tasks')) {
                _tasks = List<Map<String, dynamic>>.from(
                  decodedData['tasks'].map((e) => Map<String, dynamic>.from(e))
                );
              }
              if (decodedData.containsKey('parts')) {
                _spareParts = List<Map<String, dynamic>>.from(
                  decodedData['parts'].map((e) => Map<String, dynamic>.from(e))
                );
              }
              if (decodedData.containsKey('adminUser')) {
                _adminUsername = decodedData['adminUser'];
              }
              if (decodedData.containsKey('adminPass')) {
                _adminPassword = decodedData['adminPass'];
              }
              if (decodedData.containsKey('adminAvatar')) {
                _adminAvatarImage = decodedData['adminAvatar'];
              }
              _persistAllData();
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(widget.isArabic ? 'تم استيراد واسترجاع البيانات بنجاح' : 'Data imported successfully')),
            );
          } catch (err) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(widget.isArabic ? 'ملف غير صالح أو التنسيق خاطئ' : 'Invalid file or format')),
            );
          }
        });
      });
    }
  }

  final List<Map<String, dynamic>> _defaultTeam = [
    {
      'id': '1',
      'name': 'أحمد محمود',
      'role': 'مدير التشغيل',
      'email': 'ahmed@company.com',
      'phone': '01012345678',
      'avatarImage': null,
      'notes': <String>['التزام تـام بالحضور', 'إنجاز التقرير الشهري'],
      'evaluations': {'H1': '98%', 'H2': '96%', 'Annual': '97%'},
      'weeklyShifts': {
        'السبت': 'صباحي',
        'الأحد': 'صباحي',
        'الاثنين': 'مسائي',
        'الثلاثاء': 'موقع خارجي',
        'الأربعاء': 'صباحي',
        'الخميس': 'إجازة أسبوعية'
      }
    },
  ];

  final List<Map<String, dynamic>> _defaultTasks = [
    {
      'memberName': 'أحمد محمود',
      'title': '1- مراجعة تقرير الصيانة الدوري',
      'details': '1- فحص الماكينات رقم 01 و 02',
      'status': 'قيد التنفيذ',
      'date': '2026-10-22',
    },
  ];

  final List<Map<String, dynamic>> _defaultSpareParts = [
    {
      'machine': 'ماكينة 01',
      'partName': '1- رولمان بلي 6204\n2- جوانات إحكام صمام',
      'code': 'SP-101',
      'changeDate': '2026-10-15',
    },
  ];

  final List<String> _weekDaysAr = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  final List<String> _weekDaysEn = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday'];

  final List<String> _shiftTypesAr = [
    'صباحي', 'مسائي', 'إجازة أسبوعية', 'إجازة عادية', 'إجازة طارئة', 'إجازة عمرة', 'إجازة تعويضية', 'موقع خارجي'
  ];
  final List<String> _shiftTypesEn = [
    'Morning', 'Evening', 'Weekly', 'Normal Leave', 'Emergency Leave', 'Umrah Leave', 'Comp Leave', 'On-Site'
  ];

  String _translateDay(String dayAr) {
    int idx = _weekDaysAr.indexOf(dayAr);
    if (idx != -1 && idx < _weekDaysEn.length) {
      return _weekDaysEn[idx];
    }
    return dayAr;
  }

  String _translateShift(String shiftAr) {
    int idx = _shiftTypesAr.indexOf(shiftAr);
    if (idx != -1 && idx < _shiftTypesEn.length) {
      return _shiftTypesEn[idx];
    }
    return shiftAr;
  }

  LinearGradient _getShiftGradient(String shift) {
    if (shift.contains('صباحي') || shift.contains('Morning')) {
      return const LinearGradient(colors: [Color(0xFF00B4DB), Color(0xFF0083B0)]);
    }
    if (shift.contains('مسائي') || shift.contains('Evening')) {
      return const LinearGradient(colors: [Color(0xFFF2994A), Color(0xFFF2C94C)]);
    }
    if (shift.contains('إجازة أسبوعية') || shift.contains('Weekly')) {
      return const LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]);
    }
    if (shift.contains('إجازة عادية') || shift.contains('Normal Leave')) {
      return const LinearGradient(colors: [Color(0xFF7F7F7F), Color(0xFF3B4371)]);
    }
    if (shift.contains('إجازة طارئة') || shift.contains('Emergency')) {
      return const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]);
    }
    if (shift.contains('إجازة عمرة') || shift.contains('Umrah')) {
      return const LinearGradient(colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)]);
    }
    if (shift.contains('إجازة تعويضية') || shift.contains('Comp')) {
      return const LinearGradient(colors: [Color(0xFF4E54C8), Color(0xFF8F94FB)]);
    }
    if (shift.contains('موقع خارجي') || shift.contains('On-Site')) {
      return const LinearGradient(colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)]);
    }
    return const LinearGradient(colors: [Color(0xFF3E5151), Color(0xFFDECBA4)]);
  }

  void _toggleAdminStatus() {
    if (_isAdmin) {
      setState(() {
        _isAdmin = false;
        _selectedIndex = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isArabic ? 'تم الدخول لوضع الموظف' : 'Switched to Employee Mode'))
      );
      return;
    }
    final userInput = TextEditingController();
    final passInput = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(widget.isArabic ? 'تسجيل دخول المدير' : 'Admin Login', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 35,
              backgroundColor: Color(0xFF0284C7),
              child: Icon(Icons.admin_panel_settings, size: 35, color: Colors.white),
            ),
            const SizedBox(height: 15),
            TextField(controller: userInput, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: widget.isArabic ? 'اسم المستخدم' : 'Username', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 10),
            TextField(controller: passInput, obscureText: true, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: widget.isArabic ? 'كلمة السر' : 'Password', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            onPressed: () {
              if (userInput.text == _adminUsername && passInput.text == _adminPassword) {
                setState(() => _isAdmin = true);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(widget.isArabic ? 'بيانات الدخول غير صحيحة' : 'Invalid credentials')),
                );
              }
            },
            child: Text(widget.isArabic ? 'دخول' : 'Login'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    String? tempAdminAvatar = _adminAvatarImage;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(widget.isArabic ? 'إعدادات حساب المدير' : 'Admin Settings', style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: const Color(0xFF0284C7).withOpacity(0.2),
                          backgroundImage: (tempAdminAvatar != null && tempAdminAvatar!.isNotEmpty)
                              ? MemoryImage(base64Decode(tempAdminAvatar!.split(',').last))
                              : null,
                          child: (tempAdminAvatar == null || tempAdminAvatar!.isEmpty)
                              ? const Icon(Icons.admin_panel_settings, size: 36, color: Color(0xFF0284C7))
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF0284C7),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                              onPressed: () {
                                _pickImage((path) {
                                  setDlgState(() {
                                    tempAdminAvatar = path;
                                  });
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (tempAdminAvatar != null && tempAdminAvatar!.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setDlgState(() => tempAdminAvatar = null),
                        icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                        label: Text(widget.isArabic ? 'إزالة صورة المدير' : 'Remove admin photo', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                      ),
                    const SizedBox(height: 15),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(widget.isArabic ? 'اسم المستخدم الحالي: $_adminUsername' : 'Current Username: $_adminUsername', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        _showChangeCredentialsDialog(isUsername: true);
                      },
                      icon: const Icon(Icons.person),
                      label: Text(widget.isArabic ? 'تغيير اسم المستخدم' : 'Change Username'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        _showChangeCredentialsDialog(isUsername: false);
                      },
                      icon: const Icon(Icons.lock),
                      label: Text(widget.isArabic ? 'تغيير كلمة السر' : 'Change Password'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.white70))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                onPressed: () {
                  setState(() {
                    _adminAvatarImage = tempAdminAvatar;
                    _persistAllData();
                  });
                  Navigator.pop(context);
                },
                child: Text(widget.isArabic ? 'حفظ الصورة' : 'Save Avatar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangeCredentialsDialog({required bool isUsername}) {
    final controller = TextEditingController(text: isUsername ? _adminUsername : _adminPassword);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isUsername ? (widget.isArabic ? 'تغيير اسم المستخدم' : 'Change Username') : (widget.isArabic ? 'تغيير كلمة السر' : 'Change Password'), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          obscureText: !isUsername,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  if (isUsername) {
                    _adminUsername = controller.text;
                  } else {
                    _adminPassword = controller.text;
                  }
                  _persistAllData();
                });
                Navigator.pop(context);
              }
            },
            child: Text(widget.isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _showMemberDetailDialog(Map<String, dynamic> member) {
    String memberName = member['name'];
    List memberTasks = _tasks.where((t) => t['memberName'] == memberName).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            _buildMemberAvatar(member, radius: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(member['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white))),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.work, color: Colors.lightBlueAccent),
                  title: Text(widget.isArabic ? 'الوظيفة:' : 'Role:', style: const TextStyle(color: Colors.white70)),
                  trailing: Text(member['role'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.phone, color: Colors.lightBlueAccent),
                  title: Text(widget.isArabic ? 'الهاتف:' : 'Phone:', style: const TextStyle(color: Colors.white70)),
                  trailing: Text(member['phone'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.email, color: Colors.lightBlueAccent),
                  title: Text(widget.isArabic ? 'البريد الإلكتروني:' : 'Email:', style: const TextStyle(color: Colors.white70)),
                  trailing: Text(member['email'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const Divider(color: Colors.white24),
                Text(widget.isArabic ? 'المهام المكلف بها:' : 'Assigned Tasks:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent, fontSize: 15)),
                const SizedBox(height: 6),
                memberTasks.isEmpty
                    ? Text(widget.isArabic ? 'لا توجد مهام مسندة لهذا الموظف حالياً.' : 'No tasks assigned.', style: const TextStyle(fontSize: 13, color: Colors.white60))
                    : Column(
                        children: memberTasks.asMap().entries.map((entry) {
                          var t = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${entry.key + 1}- ${t['title']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.lightBlueAccent)),
                                const SizedBox(height: 2),
                                Text('${widget.isArabic ? "التفاصيل:" : "Details:"} ${t['details']}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                Text('${widget.isArabic ? "الحالة:" : "Status:"} ${t['status']} | ${t['date'] ?? ""}', style: const TextStyle(fontSize: 11, color: Colors.tealAccent)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                const Divider(color: Colors.white24),
                Text(widget.isArabic ? 'الملاحظات المسجلة:' : 'Registered Notes:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                const SizedBox(height: 4),
                ...((member['notes'] as List?) ?? []).asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text('${e.key + 1}- ${e.value}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                )),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isArabic ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }

  void _showTaskDetailDialog(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.task_alt, color: Colors.lightBlueAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text('${widget.isArabic ? "مهام الموظف:" : "Employee Tasks:"} ${task['memberName']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text('${widget.isArabic ? "الحالة:" : "Status:"} ${task['status']}', style: const TextStyle(color: Colors.black)),
                      backgroundColor: Colors.tealAccent.shade100,
                    ),
                    const SizedBox(width: 10),
                    Chip(
                      label: Text('${widget.isArabic ? "التاريخ:" : "Date:"} ${task['date'] ?? ""}', style: const TextStyle(color: Colors.black)),
                      backgroundColor: Colors.lightBlueAccent.shade100,
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                Text(widget.isArabic ? 'عناوين المهام:' : 'Task Titles:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent, fontSize: 14)),
                const SizedBox(height: 6),
                Text(task['title'] ?? '', style: const TextStyle(fontSize: 14, height: 1.3, color: Colors.white70)),
                const SizedBox(height: 15),
                Text(widget.isArabic ? 'التفاصيل المكلف بها:' : 'Assigned Details:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent, fontSize: 14)),
                const SizedBox(height: 6),
                Text(task['details'] ?? '', style: const TextStyle(fontSize: 14, height: 1.3, color: Colors.white70)),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isArabic ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }

  void _showPartDetailDialog(Map<String, dynamic> part) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.build, color: Colors.lightBlueAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text('${widget.isArabic ? "قطع غيار الماكينة:" : "Machine Parts:"} ${part['machine']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text('${widget.isArabic ? "الكود:" : "Code:"} ${part['code'] ?? "-"}', style: const TextStyle(color: Colors.black)),
                      backgroundColor: Colors.lightBlueAccent.shade100,
                    ),
                    const SizedBox(width: 10),
                    Chip(
                      label: Text('${widget.isArabic ? "تاريخ التغيير:" : "Date:"} ${part['changeDate'] ?? ""}', style: const TextStyle(color: Colors.black)),
                      backgroundColor: Colors.tealAccent.shade100,
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                Text(widget.isArabic ? 'القطع المستخدمة (المبدلة):' : 'Replaced Parts:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent, fontSize: 14)),
                const SizedBox(height: 8),
                Text(part['partName'] ?? '', style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.white70)),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isArabic ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }

  void _showNoteDetailDialog(Map<String, dynamic> member) {
    List notes = member['notes'] ?? [];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.note_alt, color: Colors.tealAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text('${widget.isArabic ? "ملاحظات الموظف:" : "Employee Notes:"} ${member['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: notes.isEmpty
                  ? [Text(widget.isArabic ? 'لا توجد ملاحظات مسجلة.' : 'No notes recorded.', style: const TextStyle(color: Colors.white60))]
                  : notes.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(radius: 12, backgroundColor: Colors.teal, child: Text('${entry.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 11))),
                            const SizedBox(width: 10),
                            Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 14, height: 1.3, color: Colors.white70))),
                          ],
                        ),
                      );
                    }).toList(),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isArabic ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }

  void _showAssignShiftDialog({String? memberName, String? dayToEdit, String? currentShift}) {
    if (!_isAdmin) return;
    List<String> memberNames = _teamMembers.map((m) => m['name'].toString()).toList();
    if (memberNames.isEmpty) return;

    String? selectedMemberName = memberName;
    if (selectedMemberName == null || !memberNames.contains(selectedMemberName)) {
      selectedMemberName = memberNames.first;
    }

    String selectedDay = dayToEdit ?? _weekDaysAr[0];
    String selectedShiftType = currentShift ?? _shiftTypesAr[0];
    if (!_shiftTypesAr.contains(selectedShiftType)) {
      selectedShiftType = _shiftTypesAr[0];
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(widget.isArabic ? 'تعديل / تخصيص شيفت' : 'Assign / Edit Shift', style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMemberName,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  items: memberNames.map<DropdownMenuItem<String>>((name) {
                    return DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(color: Colors.white)));
                  }).toList(),
                  onChanged: memberName != null ? null : (val) => setDialogState(() => selectedMemberName = val),
                  decoration: InputDecoration(labelText: widget.isArabic ? 'الموظف' : 'Employee', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  items: _weekDaysAr.map((d) => DropdownMenuItem(
                    value: d, 
                    child: Text(widget.isArabic ? d : _translateDay(d), style: const TextStyle(color: Colors.white))
                  )).toList(),
                  onChanged: dayToEdit != null ? null : (val) => setDialogState(() => selectedDay = val!),
                  decoration: InputDecoration(labelText: widget.isArabic ? 'اليوم' : 'Day', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedShiftType,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  items: _shiftTypesAr.map((s) => DropdownMenuItem(
                    value: s, 
                    child: Text(widget.isArabic ? s : _translateShift(s), style: const TextStyle(color: Colors.white))
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedShiftType = val!),
                  decoration: InputDecoration(labelText: widget.isArabic ? 'نوع الشيفت' : 'Shift Type', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.white70))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                onPressed: () {
                  if (selectedMemberName != null) {
                    setState(() {
                      int memberIdx = _teamMembers.indexWhere((m) => m['name'] == selectedMemberName);
                      if (memberIdx != -1) {
                        Map<String, dynamic> shifts = Map<String, dynamic>.from(_teamMembers[memberIdx]['weeklyShifts'] ?? {});
                        shifts[selectedDay] = selectedShiftType;
                        _teamMembers[memberIdx]['weeklyShifts'] = shifts;
                        _persistAllData();
                      }
                    });
                    Navigator.pop(context);
                  }
                },
                child: Text(widget.isArabic ? 'حفظ' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddMemberDialog({Map<String, dynamic>? memberToEdit, int? editIndex}) {
    if (!_isAdmin) return;
    final nameController = TextEditingController(text: memberToEdit?['name'] ?? '');
    final roleController = TextEditingController(text: memberToEdit?['role'] ?? '');
    final emailController = TextEditingController(text: memberToEdit?['email'] ?? '');
    final phoneController = TextEditingController(text: memberToEdit?['phone'] ?? '');
    String? currentAvatarImage = memberToEdit?['avatarImage'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDlg) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(memberToEdit == null ? (widget.isArabic ? 'إضافة موظف جديد' : 'Add New Member') : (widget.isArabic ? 'تعديل موظف' : 'Edit Member'), style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: const Color(0xFF0284C7).withOpacity(0.2),
                            backgroundImage: (currentAvatarImage != null && currentAvatarImage!.isNotEmpty)
                                ? MemoryImage(base64Decode(currentAvatarImage!.split(',').last))
                                : null,
                            child: (currentAvatarImage == null || currentAvatarImage!.isEmpty)
                                ? const Icon(Icons.person, size: 36, color: Color(0xFF0284C7))
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF0284C7),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                tooltip: widget.isArabic ? 'اختر صورة من الكمبيوتر' : 'Choose image from PC',
                                onPressed: () {
                                  _pickImage((path) {
                                    setStateDlg(() {
                                      currentAvatarImage = path;
                                    });
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (currentAvatarImage != null && currentAvatarImage!.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setStateDlg(() => currentAvatarImage = null),
                        icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                        label: Text(widget.isArabic ? 'إزالة الصورة الشخصية' : 'Remove picture', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                      ),
                    const SizedBox(height: 12),
                    TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: widget.isArabic ? 'اسم الموظف' : 'Name', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 10),
                    TextField(controller: roleController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: widget.isArabic ? 'الوظيفة' : 'Role', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 10),
                    TextField(controller: emailController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: widget.isArabic ? 'البريد الإلكتروني' : 'Email', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 10),
                    TextField(controller: phoneController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: widget.isArabic ? 'رقم الهاتف' : 'Phone', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.white70))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    setState(() {
                      if (memberToEdit == null) {
                        _teamMembers.add({
                          'id': DateTime.now().toString(),
                          'name': nameController.text,
                          'role': roleController.text,
                          'email': emailController.text,
                          'phone': phoneController.text,
                          'avatarImage': currentAvatarImage,
                          'notes': <String>[],
                          'evaluations': {'H1': '90%', 'H2': '90%', 'Annual': '90%'},
                          'weeklyShifts': <String, String>{},
                        });
                      } else {
                        _teamMembers[editIndex!] = {
                          ...memberToEdit,
                          'name': nameController.text,
                          'role': roleController.text,
                          'email': emailController.text,
                          'phone': phoneController.text,
                          'avatarImage': currentAvatarImage,
                        };
                      }
                      _persistAllData();
                    });
                    Navigator.pop(context);
                  }
                },
                child: Text(widget.isArabic ? 'حفظ' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddTaskDialog({Map<String, dynamic>? taskToEdit, int? editIndex}) {
    if (!_isAdmin) return;
    List<String> memberNames = _teamMembers.map((m) => m['name'].toString()).toList();
    if (memberNames.isEmpty) return;

    String? selectedName = taskToEdit?['memberName'];
    if (selectedName == null || !memberNames.contains(selectedName)) {
      selectedName = memberNames.first;
    }

    List<String> rawTitles = [];
    if (taskToEdit != null && taskToEdit['title'] != null) {
      rawTitles = taskToEdit['title'].toString().split('\n').map((e) => e.replaceFirst(RegExp(r'^\d+[\.\-]\s*'), '').trim()).where((e) => e.isNotEmpty).toList();
    }
    if (rawTitles.isEmpty) rawTitles = [''];

    List<String> rawDetails = [];
    if (taskToEdit != null && taskToEdit['details'] != null) {
      rawDetails = taskToEdit['details'].toString().split('\n').map((e) => e.replaceFirst(RegExp(r'^\d+[\.\-]\s*'), '').trim()).where((e) => e.isNotEmpty).toList();
    }
    if (rawDetails.isEmpty) rawDetails = [''];

    List<TextEditingController> titleControllers = rawTitles.map((t) => TextEditingController(text: t)).toList();
    List<TextEditingController> detailControllers = rawDetails.map((d) => TextEditingController(text: d)).toList();

    String status = taskToEdit?['status'] ?? 'قيد الانتظار';
    String selectedDate = taskToEdit?['date'] ?? DateTime.now().toString().split(' ')[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setTaskState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(taskToEdit == null ? (widget.isArabic ? 'إسناد مهمة جديدة متسلسلة' : 'Assign Sequenced Task') : (widget.isArabic ? 'تعديل المهمة المتسلسلة' : 'Edit Sequenced Task'), style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedName,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      items: memberNames.map<DropdownMenuItem<String>>((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (val) => setTaskState(() => selectedName = val),
                      decoration: InputDecoration(labelText: widget.isArabic ? 'الموظف' : 'Employee', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 15),
                    Text(widget.isArabic ? 'عناوين المهام (مرقمة آلياً):' : 'Task Titles (Auto-numbered):', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
                    const SizedBox(height: 8),
                    ...titleControllers.asMap().entries.map((entry) {
                      int idx = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 14, backgroundColor: const Color(0xFF0284C7), child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: titleControllers[idx],
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: widget.isArabic ? 'اكتب عنوان المهمة رقم ${idx + 1}' : 'Enter task title',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            if (titleControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22),
                                onPressed: () {
                                  setTaskState(() {
                                    titleControllers.removeAt(idx);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setTaskState(() {
                            titleControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.lightBlueAccent),
                        label: Text(widget.isArabic ? 'إضافة عنوان مهمة آخر' : 'Add another title', style: const TextStyle(color: Colors.lightBlueAccent)),
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 25),
                    Text(widget.isArabic ? 'تفاصيل المهام (مرقمة آلياً):' : 'Task Details (Auto-numbered):', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
                    const SizedBox(height: 8),
                    ...detailControllers.asMap().entries.map((entry) {
                      int idx = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 14, backgroundColor: const Color(0xFF0369A1), child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: detailControllers[idx],
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: widget.isArabic ? 'اكتب تفصيل المهمة رقم ${idx + 1}' : 'Enter task detail',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            if (detailControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22),
                                onPressed: () {
                                  setTaskState(() {
                                    detailControllers.removeAt(idx);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setTaskState(() {
                            detailControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.lightBlueAccent),
                        label: Text(widget.isArabic ? 'إضافة تفصيل آخر' : 'Add another detail', style: const TextStyle(color: Colors.lightBlueAccent)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: Text('${widget.isArabic ? "التاريخ:" : "Date:"} $selectedDate', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        TextButton(
                          onPressed: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.tryParse(selectedDate) ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setTaskState(() {
                                selectedDate = picked.toString().split(' ')[0];
                              });
                            }
                          },
                          child: Text(widget.isArabic ? 'اختيار التاريخ' : 'Pick Date', style: const TextStyle(color: Colors.lightBlueAccent)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.white70))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                onPressed: () {
                  if (selectedName != null) {
                    List<String> validTitles = [];
                    for (int i = 0; i < titleControllers.length; i++) {
                      String val = titleControllers[i].text.trim();
                      if (val.isNotEmpty) {
                        validTitles.add('${validTitles.length + 1}- $val');
                      }
                    }

                    List<String> validDetails = [];
                    for (int i = 0; i < detailControllers.length; i++) {
                      String val = detailControllers[i].text.trim();
                      if (val.isNotEmpty) {
                        validDetails.add('${validDetails.length + 1}- $val');
                      }
                    }

                    if (validTitles.isNotEmpty) {
                      setState(() {
                        final newTaskData = {
                          'memberName': selectedName,
                          'title': validTitles.join('\n'),
                          'details': validDetails.join('\n'),
                          'status': status,
                          'date': selectedDate,
                        };

                        if (taskToEdit == null) {
                          _tasks.add(newTaskData);
                        } else {
                          if (editIndex != null && editIndex >= 0 && editIndex < _tasks.length) {
                            _tasks[editIndex] = newTaskData;
                          } else {
                            int foundIdx = _tasks.indexOf(taskToEdit);
                            if (foundIdx != -1) {
                              _tasks[foundIdx] = newTaskData;
                            } else {
                              _tasks.add(newTaskData);
                            }
                          }
                        }
                        _persistAllData();
                      });
                      Navigator.pop(context);
                    }
                  }
                },
                child: Text(widget.isArabic ? 'حفظ' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddPartDialog({Map<String, dynamic>? partToEdit, int? editIndex}) {
    if (!_isAdmin) return;
    final machineCtrl = TextEditingController(text: partToEdit?['machine'] ?? '');
    final codeCtrl = TextEditingController(text: partToEdit?['code'] ?? '');
    String selectedDate = partToEdit?['changeDate'] ?? DateTime.now().toString().split(' ')[0];

    List<String> rawParts = [];
    if (partToEdit != null && partToEdit['partName'] != null) {
      rawParts = partToEdit['partName'].toString().split('\n').map((e) => e.replaceFirst(RegExp(r'^\d+[\.\-]\s*'), '').trim()).where((e) => e.isNotEmpty).toList();
    }
    if (rawParts.isEmpty) rawParts = [''];

    List<TextEditingController> partControllers = rawParts.map((p) => TextEditingController(text: p)).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setPartState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(partToEdit == null ? (widget.isArabic ? 'إضافة قطع غيار متسلسلة للماكينة' : 'Add Sequenced Spare Parts') : (widget.isArabic ? 'تعديل قطع الغيار' : 'Edit Spare Parts'), style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: machineCtrl, 
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: widget.isArabic ? 'اسم الماكينة' : 'Machine Name',
                        labelStyle: const TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl, 
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: widget.isArabic ? 'كود الصيانة / الطلب' : 'Code',
                        labelStyle: const TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(widget.isArabic ? 'أسماء قطع الغيار (مرقمة آلياً):' : 'Spare Parts (Auto-numbered):', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
                    const SizedBox(height: 8),
                    ...partControllers.asMap().entries.map((entry) {
                      int idx = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(radius: 14, backgroundColor: const Color(0xFF0EA5E9), child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: partControllers[idx],
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: widget.isArabic ? 'اكتب اسم القطعة رقم ${idx + 1}' : 'Enter part name',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            if (partControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22),
                                onPressed: () {
                                  setPartState(() {
                                    partControllers.removeAt(idx);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setPartState(() {
                            partControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.lightBlueAccent),
                        label: Text(widget.isArabic ? 'إضافة قطعة أخرى' : 'Add another part', style: const TextStyle(color: Colors.lightBlueAccent)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: Text('${widget.isArabic ? "تاريخ التغيير:" : "Change Date:"} $selectedDate', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        TextButton(
                          onPressed: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.tryParse(selectedDate) ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setPartState(() {
                                selectedDate = picked.toString().split(' ')[0];
                              });
                            }
                          },
                          child: Text(widget.isArabic ? 'اختيار التاريخ' : 'Pick Date', style: const TextStyle(color: Colors.lightBlueAccent)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.white70))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
                onPressed: () {
                  if (machineCtrl.text.isNotEmpty) {
                    List<String> validParts = [];
                    for (int i = 0; i < partControllers.length; i++) {
                      String val = partControllers[i].text.trim();
                      if (val.isNotEmpty) {
                        validParts.add('${validParts.length + 1}- $val');
                      }
                    }

                    if (validParts.isNotEmpty) {
                      setState(() {
                        final newPartData = {
                          'machine': machineCtrl.text,
                          'partName': validParts.join('\n'),
                          'code': codeCtrl.text,
                          'changeDate': selectedDate,
                        };

                        if (partToEdit == null) {
                          _spareParts.add(newPartData);
                        } else {
                          if (editIndex != null && editIndex >= 0 && editIndex < _spareParts.length) {
                            _spareParts[editIndex] = newPartData;
                          } else {
                            int foundIdx = _spareParts.indexOf(partToEdit);
                            if (foundIdx != -1) {
                              _spareParts[foundIdx] = newPartData;
                            } else {
                              _spareParts.add(newPartData);
                            }
                          }
                        }
                        _persistAllData();
                      });
                      Navigator.pop(context);
                    }
                  }
                },
                child: Text(widget.isArabic ? 'حفظ' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddNoteDialog({Map<String, dynamic>? memberToEdit, String? existingNote, int? noteIndex}) {
    if (!_isAdmin) return;
    List<String> memberNames = _teamMembers.map((m) => m['name'].toString()).toList();
    if (memberNames.isEmpty) return;

    String? selectedName = memberToEdit?['name'];
    if (selectedName == null || !memberNames.contains(selectedName)) {
      selectedName = memberNames.first;
    }

    final noteCtrl = TextEditingController(text: existingNote ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setNoteState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(existingNote == null ? (widget.isArabic ? 'إضافة ملاحظات (عدة نقاط)' : 'Add Notes (Multiple)') : (widget.isArabic ? 'تعديل الملاحظة' : 'Edit Note'), style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedName,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    items: memberNames.map<DropdownMenuItem<String>>((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: memberToEdit != null ? null : (val) => setNoteState(() => selectedName = val),
                    decoration: InputDecoration(labelText: widget.isArabic ? 'اختر الموظف' : 'Select Employee', labelStyle: const TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      labelText: existingNote == null ? (widget.isArabic ? 'اكتب الملاحظات (كل سطر يعتبر نقطة مستقلة)' : 'Enter notes (Each line is a point)') : (widget.isArabic ? 'تعديل الملاحظة' : 'Edit note'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.white70))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                onPressed: () {
                  if (selectedName != null && noteCtrl.text.isNotEmpty) {
                    setState(() {
                      int idx = _teamMembers.indexWhere((m) => m['name'] == selectedName);
                      if (idx != -1) {
                        List notes = List.from(_teamMembers[idx]['notes'] ?? []);
                        if (existingNote != null && noteIndex != null) {
                          notes[noteIndex] = noteCtrl.text;
                        } else {
                          List<String> newLines = noteCtrl.text
                              .split('\n')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();
                          notes.addAll(newLines);
                        }
                        _teamMembers[idx]['notes'] = notes;
                        _persistAllData();
                      }
                    });
                    Navigator.pop(context);
                  }
                },
                child: Text(widget.isArabic ? 'حفظ' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMemberAvatar(Map<String, dynamic> member, {double radius = 20}) {
    String? avatarImage = member['avatarImage'];
    if (avatarImage != null && avatarImage.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(base64Decode(avatarImage.split(',').last)),
        );
      } catch (e) {
        // Fallback
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.lightBlueAccent.withOpacity(0.2),
      child: Icon(Icons.person, color: Colors.lightBlueAccent, size: radius * 1.2),
    );
  }

  String _getCurrentPageTitle() {
    if (widget.isArabic) {
      if (_isAdmin) {
        switch (_selectedIndex) {
          case 0: return 'XELO WM - الرئيسية';
          case 1: return 'الشيفتات';
          case 2: return 'الفريق';
          case 3: return 'المهام';
          case 4: return 'قطع الغيار';
          case 5: return 'الملاحظات';
          case 6: return 'التقييمات';
          default: return 'XELO WM';
        }
      } else {
        switch (_selectedIndex) {
          case 0: return 'XELO WM - الرئيسية';
          case 1: return 'الشيفتات';
          case 2: return 'الفريق';
          case 3: return 'قطع الغيار';
          default: return 'XELO WM';
        }
      }
    } else {
      if (_isAdmin) {
        switch (_selectedIndex) {
          case 0: return 'XELO WM - Home';
          case 1: return 'Shifts';
          case 2: return 'Team';
          case 3: return 'Tasks';
          case 4: return 'Parts';
          case 5: return 'Notes';
          case 6: return 'Evaluations';
          default: return 'XELO WM';
        }
      } else {
        switch (_selectedIndex) {
          case 0: return 'XELO WM - Home';
          case 1: return 'Shifts';
          case 2: return 'Team';
          case 3: return 'Parts';
          default: return 'XELO WM';
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> sectionBackgrounds = _isAdmin ? [
      'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1920&q=80', // الرئيسية
      'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1920&q=80', // الشيفتات
      'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=1920&q=80', // الفريق
      'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?auto=format&fit=crop&w=1920&q=80', // المهام
      'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1920&q=80', // قطع الغيار
      'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1920&q=80', // الملاحظات
      'https://images.unsplash.com/photo-1460925895917-afdab827c52f?auto=format&fit=crop&w=1920&q=80', // التقييمات
    ] : [
      'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1920&q=80',
      'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=1920&q=80',
      'https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&w=1920&q=80',
      'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1920&q=80',
    ];

    int activeIdx = _selectedIndex < sectionBackgrounds.length ? _selectedIndex : 0;
    String currentBgUrl = sectionBackgrounds[activeIdx];

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(currentBgUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.black.withOpacity(0.35),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.black.withOpacity(0.45),
            title: Text(
              _getCurrentPageTitle(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white, shadows: [Shadow(blurRadius: 6, color: Colors.black, offset: Offset(0, 2))]),
            ),
            actions: [
              if (_isAdmin) ...[
                IconButton(
                  tooltip: widget.isArabic ? 'تصدير نسخة احتياطية (Backup)' : 'Export Backup',
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: _exportData,
                ),
                IconButton(
                  tooltip: widget.isArabic ? 'استيراد نسخة احتياطية (Restore)' : 'Import Backup',
                  icon: const Icon(Icons.upload, color: Colors.white),
                  onPressed: _importData,
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      backgroundImage: (_adminAvatarImage != null && _adminAvatarImage!.isNotEmpty)
                          ? MemoryImage(base64Decode(_adminAvatarImage!.split(',').last))
                          : null,
                      child: (_adminAvatarImage == null || _adminAvatarImage!.isEmpty)
                          ? const Icon(Icons.admin_panel_settings, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Text(_adminUsername, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
                  ],
                ),
                IconButton(
                  tooltip: widget.isArabic ? 'إعدادات المدير' : 'Admin Settings',
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: _showSettingsDialog,
                ),
              ],
              IconButton(icon: const Icon(Icons.language, color: Colors.white), onPressed: widget.onToggleLanguage),
              IconButton(
                icon: Icon(_isAdmin ? Icons.admin_panel_settings : Icons.lock_outline, color: _isAdmin ? Colors.cyanAccent : Colors.white),
                onPressed: _toggleAdminStatus,
              ),
            ],
          ),
          body: ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
            child: Container(
              color: Colors.black.withOpacity(0.2),
              child: IndexedStack(
                index: _selectedIndex,
                children: _isAdmin ? [
                  _buildHomeOverviewTab(),
                  _buildShiftsTableTab(),
                  _buildTeamProfileTab(),
                  _buildTasksTab(),
                  _buildSparePartsTab(),
                  _buildNotesTab(),
                  _buildEvaluationsTab(),
                ] : [
                  _buildHomeOverviewTab(),
                  _buildShiftsTableTab(),
                  _buildTeamProfileTab(),
                  _buildSparePartsTab(),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: _selectedIndex < (_isAdmin ? 7 : 4) ? _selectedIndex : 0,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              backgroundColor: Colors.transparent,
              indicatorColor: Colors.white24,
              destinations: _isAdmin ? [
                NavigationDestination(icon: const Icon(Icons.dashboard, color: Colors.white70), selectedIcon: const Icon(Icons.dashboard, color: Colors.white), label: widget.isArabic ? 'الرئيسية' : 'Home'),
                NavigationDestination(icon: const Icon(Icons.calendar_month, color: Colors.white70), selectedIcon: const Icon(Icons.calendar_month, color: Colors.white), label: widget.isArabic ? 'الشيفتات' : 'Shifts'),
                NavigationDestination(icon: const Icon(Icons.badge, color: Colors.white70), selectedIcon: const Icon(Icons.badge, color: Colors.white), label: widget.isArabic ? 'الفريق' : 'Team'),
                NavigationDestination(icon: const Icon(Icons.task_alt, color: Colors.white70), selectedIcon: const Icon(Icons.task_alt, color: Colors.white), label: widget.isArabic ? 'المهام' : 'Tasks'),
                NavigationDestination(icon: const Icon(Icons.build, color: Colors.white70), selectedIcon: const Icon(Icons.build, color: Colors.white), label: widget.isArabic ? 'قطع الغيار' : 'Parts'),
                NavigationDestination(icon: const Icon(Icons.note_alt, color: Colors.white70), selectedIcon: const Icon(Icons.note_alt, color: Colors.white), label: widget.isArabic ? 'الملاحظات' : 'Notes'),
                NavigationDestination(icon: const Icon(Icons.star, color: Colors.white70), selectedIcon: const Icon(Icons.star, color: Colors.white), label: widget.isArabic ? 'التقييمات' : 'Evals'),
              ] : [
                NavigationDestination(icon: const Icon(Icons.dashboard, color: Colors.white70), selectedIcon: const Icon(Icons.dashboard, color: Colors.white), label: widget.isArabic ? 'الرئيسية' : 'Home'),
                NavigationDestination(icon: const Icon(Icons.calendar_month, color: Colors.white70), selectedIcon: const Icon(Icons.calendar_month, color: Colors.white), label: widget.isArabic ? 'الشيفتات' : 'Shifts'),
                NavigationDestination(icon: const Icon(Icons.badge, color: Colors.white70), selectedIcon: const Icon(Icons.badge, color: Colors.white), label: widget.isArabic ? 'الفريق' : 'Team'),
                NavigationDestination(icon: const Icon(Icons.build, color: Colors.white70), selectedIcon: const Icon(Icons.build, color: Colors.white), label: widget.isArabic ? 'قطع الغيار' : 'Parts'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeOverviewTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 900;
          
          Widget sectionsTableWidget = Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart, color: Colors.cyanAccent, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      widget.isArabic ? 'جدول معلومات الأقسام' : 'Sections Information Table',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.black54),
                    columnSpacing: 28,
                    columns: [
                      DataColumn(label: Text(widget.isArabic ? 'م' : 'No.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.cyanAccent))),
                      DataColumn(label: Text(widget.isArabic ? 'القسم' : 'Section', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.cyanAccent))),
                      DataColumn(label: Text(widget.isArabic ? 'الوصف المختصر' : 'Description', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white70))),
                    ],
                    rows: [
                      DataRow(
                        onSelectChanged: (_) => setState(() => _selectedIndex = 1),
                        cells: [
                          DataCell(const Text('1', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
                          DataCell(Text(widget.isArabic ? 'الشيفتات' : 'Shifts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          DataCell(Text(widget.isArabic ? 'جدول أسبوعي للورديات والإجازات' : 'Weekly schedule for shifts and leaves', style: const TextStyle(color: Colors.white70))),
                        ],
                      ),
                      DataRow(
                        onSelectChanged: (_) => setState(() => _selectedIndex = 2),
                        cells: [
                          DataCell(const Text('2', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
                          DataCell(Text(widget.isArabic ? 'فريق العمل' : 'Team', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          DataCell(Text(widget.isArabic ? 'إدارة الكوادر والصور والبيانات' : 'Management of staff and profiles', style: const TextStyle(color: Colors.white70))),
                        ],
                      ),
                      DataRow(
                        onSelectChanged: (_) {
                          if (_isAdmin) setState(() => _selectedIndex = 3);
                        },
                        cells: [
                          DataCell(const Text('3', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
                          DataCell(Text(widget.isArabic ? 'المهام' : 'Tasks', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          DataCell(Text(widget.isArabic ? 'إسناد ومتابعة المهام اليومية' : 'Assignment and tracking of daily tasks', style: const TextStyle(color: Colors.white70))),
                        ],
                      ),
                      DataRow(
                        onSelectChanged: (_) {
                          int partIdx = _isAdmin ? 4 : 3;
                          setState(() => _selectedIndex = partIdx);
                        },
                        cells: [
                          DataCell(const Text('4', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
                          DataCell(Text(widget.isArabic ? 'قطع الغيار' : 'Spare Parts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          DataCell(Text(widget.isArabic ? 'تتبع وصيانة قطع الغيار' : 'Tracking and maintenance of spare parts', style: const TextStyle(color: Colors.white70))),
                        ],
                      ),
                      DataRow(
                        onSelectChanged: (_) {
                          if (_isAdmin) setState(() => _selectedIndex = 5);
                        },
                        cells: [
                          DataCell(const Text('5', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
                          DataCell(Text(widget.isArabic ? 'الملاحظات' : 'Notes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          DataCell(Text(widget.isArabic ? 'تدوين ومتابعة الملاحظات الإدارية' : 'Recording and tracking administrative notes', style: const TextStyle(color: Colors.white70))),
                        ],
                      ),
                      DataRow(
                        onSelectChanged: (_) {
                          if (_isAdmin) setState(() => _selectedIndex = 6);
                        },
                        cells: [
                          DataCell(const Text('6', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
                          DataCell(Text(widget.isArabic ? 'التقييمات' : 'Evaluations', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          DataCell(Text(widget.isArabic ? 'تقييمات الأداء النصف سنوية والسنوية' : 'Semi-annual and annual performance reviews', style: const TextStyle(color: Colors.white70))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          Widget administrativeLogoWidget = ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              constraints: const BoxConstraints(minHeight: 380),
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1497215728101-856f4ea42174?auto=format&fit=crop&w=1600&q=80'),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: const Text(
                      'XELO',
                      style: TextStyle(
                        fontSize: 82,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 14,
                        color: Colors.white,
                        shadows: [
                          Shadow(blurRadius: 30, color: Colors.cyanAccent, offset: Offset(0, 3)),
                          Shadow(blurRadius: 10, color: Colors.black, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Work Manager',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 6,
                        color: Colors.cyanAccent.shade100,
                        shadows: const [
                          Shadow(blurRadius: 15, color: Colors.black, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: sectionsTableWidget),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: administrativeLogoWidget),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: Column(
                children: [
                  sectionsTableWidget,
                  const SizedBox(height: 20),
                  administrativeLogoWidget,
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildShiftsTableTab() {
    List<String> days = widget.isArabic ? _weekDaysAr : _weekDaysEn;
    var filteredMembers = _teamMembers.where((m) => m['name'].toLowerCase().contains(_searchShifts.toLowerCase())).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.isArabic ? 'جدول الشيفتات الأسبوعي (من السبت للخميس)' : 'Weekly Shifts Table', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
              if (_isAdmin)
                ElevatedButton.icon(
                  onPressed: () => _showAssignShiftDialog(),
                  icon: const Icon(Icons.add),
                  label: Text(widget.isArabic ? 'تخصيص شيفت' : 'Assign Shift'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (val) => setState(() => _searchShifts = val),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.isArabic ? 'بحث باسم الموظف...' : 'Search employee...',
              hintStyle: const TextStyle(color: Colors.white60),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.black.withOpacity(0.4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.black45),
                    columnSpacing: 44,
                    columns: [
                      DataColumn(label: Text(widget.isArabic ? 'الموظف' : 'Employee', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      ...days.map((day) => DataColumn(label: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))),
                      if (_isAdmin) const DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filteredMembers.map((m) {
                      Map shifts = m['weeklyShifts'] ?? {};
                      return DataRow(
                        cells: [
                          DataCell(
                            InkWell(
                              onTap: () => _showMemberDetailDialog(m),
                              child: Row(
                                children: [
                                  _buildMemberAvatar(m, radius: 16),
                                  const SizedBox(width: 8),
                                  Text(m['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          ..._weekDaysAr.map((dayAr) {
                            String shiftVal = shifts[dayAr] ?? '-';
                            String displayShift = widget.isArabic ? shiftVal : _translateShift(shiftVal);
                            return DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: _isAdmin ? () => _showAssignShiftDialog(memberName: m['name'], dayToEdit: dayAr, currentShift: shiftVal) : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: _getShiftGradient(shiftVal),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        displayShift, 
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 2, color: Colors.black45)]),
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ),
                                  if (_isAdmin && shiftVal != '-') ...[
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          Map<String, dynamic> updatedShifts = Map<String, dynamic>.from(m['weeklyShifts']);
                                          updatedShifts.remove(dayAr);
                                          m['weeklyShifts'] = updatedShifts;
                                          _persistAllData();
                                        });
                                      },
                                      child: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                          if (_isAdmin)
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.lightBlueAccent, size: 20),
                                onPressed: () => _showAssignShiftDialog(memberName: m['name']),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamProfileTab() {
    var filtered = _teamMembers.where((m) => m['name'].toLowerCase().contains(_searchTeam.toLowerCase()) || m['role'].toLowerCase().contains(_searchTeam.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchTeam = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: widget.isArabic ? 'بحث في فريق العمل...' : 'Search team...',
                    hintStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showAddMemberDialog(),
                  icon: const Icon(Icons.add),
                  label: Text(widget.isArabic ? 'إضافة عضو' : 'Add Member'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final m = filtered[index];
              return Card(
                color: const Color(0xFF0F172A).withOpacity(0.7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white24)),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: _buildMemberAvatar(m, radius: 22),
                  title: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text('${m['role']} - ${m['phone']}', style: const TextStyle(color: Colors.white70)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.tealAccent),
                        tooltip: widget.isArabic ? 'عرض التفاصيل' : 'View Details',
                        onPressed: () => _showMemberDetailDialog(m),
                      ),
                      if (_isAdmin) ...[
                        IconButton(icon: const Icon(Icons.edit, color: Colors.lightBlueAccent), onPressed: () => _showAddMemberDialog(memberToEdit: m, editIndex: _teamMembers.indexOf(m))),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () {
                          setState(() {
                            _teamMembers.remove(m);
                            _persistAllData();
                          });
                        }),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTasksTab() {
    var filtered = _tasks.where((t) => t['title'].toLowerCase().contains(_searchTasks.toLowerCase()) || t['memberName'].toLowerCase().contains(_searchTasks.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchTasks = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: widget.isArabic ? 'بحث في المهام...' : 'Search tasks...',
                    hintStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showAddTaskDialog(),
                  icon: const Icon(Icons.add),
                  label: Text(widget.isArabic ? 'إسناد مهمة' : 'Assign Task'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final t = filtered[index];
              return Card(
                color: const Color(0xFF0F172A).withOpacity(0.7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white24)),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: Colors.lightBlueAccent, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                t['memberName'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.lightBlueAccent),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, color: Colors.tealAccent, size: 20),
                                tooltip: widget.isArabic ? 'عرض تفاصيل المهمة' : 'View Task Details',
                                onPressed: () => _showTaskDetailDialog(t),
                              ),
                              if (_isAdmin) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.lightBlueAccent, size: 20),
                                  onPressed: () => _showAddTaskDialog(taskToEdit: t, editIndex: _tasks.indexOf(t)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _tasks.remove(t);
                                      _persistAllData();
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 14),
                      Text(
                        widget.isArabic ? 'عناوين المهام:' : 'Task Titles:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t['title'],
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Chip(
                            label: Text('${t['status']} | ${t['date'] ?? ""}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                            backgroundColor: Colors.lightBlueAccent.shade100,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSparePartsTab() {
    var filtered = _spareParts.where((p) => p['partName'].toLowerCase().contains(_searchParts.toLowerCase()) || p['machine'].toLowerCase().contains(_searchParts.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchParts = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: widget.isArabic ? 'بحث في قطع الغيار...' : 'Search parts...',
                    hintStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showAddPartDialog(),
                  icon: const Icon(Icons.add),
                  label: Text(widget.isArabic ? 'إضافة قطعة' : 'Add Part'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final p = filtered[index];
              return Card(
                color: const Color(0xFF0F172A).withOpacity(0.7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white24)),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.build, color: Colors.lightBlueAccent, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                p['machine'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.lightBlueAccent),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, color: Colors.tealAccent, size: 20),
                                tooltip: widget.isArabic ? 'عرض تفاصيل قطع الغيار' : 'View Part Details',
                                onPressed: () => _showPartDetailDialog(p),
                              ),
                              if (_isAdmin) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.lightBlueAccent, size: 20),
                                  onPressed: () => _showAddPartDialog(partToEdit: p, editIndex: _spareParts.indexOf(p)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _spareParts.remove(p);
                                      _persistAllData();
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 14),
                      Text(
                        widget.isArabic ? 'القطع المستخدمة:' : 'Replaced Parts:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p['partName'],
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Chip(
                            label: Text('${p['code'] ?? ""} | ${p['changeDate'] ?? ""}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                            backgroundColor: Colors.tealAccent.shade100,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotesTab() {
    var filteredMembers = _teamMembers.where((m) => m['name'].toLowerCase().contains(_searchNotes.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchNotes = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: widget.isArabic ? 'بحث في الملاحظات...' : 'Search notes...',
                    hintStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showAddNoteDialog(),
                  icon: const Icon(Icons.add),
                  label: Text(widget.isArabic ? 'إضافة ملاحظة' : 'Add Note'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredMembers.length,
            itemBuilder: (context, index) {
              final m = filteredMembers[index];
              List notes = m['notes'] ?? [];
              return Card(
                color: const Color(0xFF0F172A).withOpacity(0.7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white24)),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: _buildMemberAvatar(m, radius: 22),
                  title: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text(
                    notes.isNotEmpty ? notes.first : (widget.isArabic ? 'لا توجد ملاحظات' : 'No notes'),
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.tealAccent, size: 20),
                        tooltip: widget.isArabic ? 'عرض كل الملاحظات' : 'View All Notes',
                        onPressed: () => _showNoteDetailDialog(m),
                      ),
                      if (_isAdmin) ...[
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.tealAccent),
                          onPressed: () => _showAddNoteDialog(memberToEdit: m),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddEvaluationDialog({Map<String, dynamic>? memberToEdit}) {
    if (!_isAdmin) return;
    List<String> memberNames = _teamMembers.map((m) => m['name'].toString()).toList();
    if (memberNames.isEmpty) return;

    String? selectedName = memberToEdit?['name'];
    if (selectedName == null || !memberNames.contains(selectedName)) {
      selectedName = memberNames.first;
    }

    Map evals = memberToEdit?['evaluations'] ?? {'H1': '90%', 'H2': '90%', 'Annual': '90%'};
    final h1Ctrl = TextEditingController(text: evals['H1']);
    final h2Ctrl = TextEditingController(text: evals['H2']);
    final annualCtrl = TextEditingController(text: evalzValue(evals['Annual']));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B).withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(widget.isArabic ? 'تعديل وتقييم الأداء' : 'Edit Evaluation', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedName,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              items: memberNames.map<DropdownMenuItem<String>>((name) => DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: memberToEdit != null ? null : (val) => selectedName = val,
              decoration: InputDecoration(labelText: widget.isArabic ? 'اختر الموظف' : 'Select Employee', labelStyle: const TextStyle(color: Colors.white70)),
            ),
            TextField(controller: h1Ctrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'H1', labelStyle: TextStyle(color: Colors.white70))),
            TextField(controller: h2Ctrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'H2', labelStyle: TextStyle(color: Colors.white70))),
            TextField(controller: annualCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Annual', labelStyle: TextStyle(color: Colors.white70))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0369A1), foregroundColor: Colors.white),
            onPressed: () {
              if (selectedName != null) {
                setState(() {
                  int idx = _teamMembers.indexWhere((m) => m['name'] == selectedName);
                  if (idx != -1) {
                    _teamMembers[idx]['evaluations'] = {
                      'H1': h1Ctrl.text,
                      'H2': h2Ctrl.text,
                      'Annual': annualCtrl.text,
                    };
                    _persistAllData();
                  }
                });
                Navigator.pop(context);
              }
            },
            child: Text(widget.isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  String evalzValue(dynamic val) => val?.toString() ?? '90%';

  Widget _evaluationsTab() {
    return _buildEvaluationsTab();
  }

  Widget _buildEvaluationsTab() {
    var filteredMembers = _teamMembers.where((m) => m['name'].toLowerCase().contains(_searchEvals.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchEvals = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: widget.isArabic ? 'بحث في التقييمات...' : 'Search evaluations...',
                    hintStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showAddEvaluationDialog(),
                  icon: const Icon(Icons.add),
                  label: Text(widget.isArabic ? 'تعديل التقييم' : 'Edit Eval'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0369A1), foregroundColor: Colors.white),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredMembers.length,
            itemBuilder: (context, index) {
              final m = filteredMembers[index];
              Map evals = m['evaluations'] ?? {};
              return Card(
                color: const Color(0xFF0F172A).withOpacity(0.7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white24)),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: _buildMemberAvatar(m, radius: 22),
                  title: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text('H1: ${evals['H1']} | H2: ${evals['H2']} | Annual: ${evals['Annual']}', style: const TextStyle(color: Colors.white70)),
                  trailing: _isAdmin ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.lightBlueAccent),
                        onPressed: () => _showAddEvaluationDialog(memberToEdit: m),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: widget.isArabic ? 'تصفير التقييمات' : 'Reset evaluations',
                        onPressed: () {
                          setState(() {
                            m['evaluations'] = {'H1': '0%', 'H2': '0%', 'Annual': '0%'};
                            _persistAllData();
                          });
                        },
                      ),
                    ],
                  ) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}