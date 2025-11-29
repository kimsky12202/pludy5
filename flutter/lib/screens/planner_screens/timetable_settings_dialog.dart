// lib/screens/planner_screens/timetable_settings_dialog.dart
// 시간표 커스터마이징 설정 다이얼로그
import 'package:flutter/material.dart';

class TimetableSettingsDialog extends StatefulWidget {
  final String fontFamily;
  final String penType;

  const TimetableSettingsDialog({
    super.key,
    required this.fontFamily,
    required this.penType,
  });

  @override
  State<TimetableSettingsDialog> createState() =>
      _TimetableSettingsDialogState();
}

class _TimetableSettingsDialogState extends State<TimetableSettingsDialog> {
  late String _selectedFontFamily;
  late String _selectedPenType;

  final List<String> _fontFamilies = [
    '기본',
    '고딕',
    '명조',
    '손글씨',
    '둥근',
  ];

  final List<String> _penTypes = [
    '볼펜',
    '싸인펜',
    '형광펜',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFontFamily = widget.fontFamily;
    _selectedPenType = widget.penType;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('시간표 커스터마이징'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 글씨체 선택
          DropdownButtonFormField<String>(
            value: _selectedFontFamily,
            decoration: const InputDecoration(
              labelText: '글씨체',
              border: OutlineInputBorder(),
            ),
            items: _fontFamilies.map((font) {
              return DropdownMenuItem(
                value: font,
                child: Text(font),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedFontFamily = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          // 펜 종류 선택
          DropdownButtonFormField<String>(
            value: _selectedPenType,
            decoration: const InputDecoration(
              labelText: '펜 종류',
              border: OutlineInputBorder(),
            ),
            items: _penTypes.map((pen) {
              return DropdownMenuItem(
                value: pen,
                child: Row(
                  children: [
                    _getPenIcon(pen),
                    const SizedBox(width: 8),
                    Text(pen),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedPenType = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          // 미리보기
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '미리보기',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '시간표 텍스트',
                  style: _getTextStyle(),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'fontFamily': _selectedFontFamily,
              'penType': _selectedPenType,
            });
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  // 펜 아이콘
  Widget _getPenIcon(String penType) {
    switch (penType) {
      case '볼펜':
        return const Icon(Icons.edit, size: 20);
      case '싸인펜':
        return const Icon(Icons.brush, size: 20);
      case '형광펜':
        return const Icon(Icons.highlight, size: 20, color: Colors.yellow);
      default:
        return const Icon(Icons.edit, size: 20);
    }
  }

  // 텍스트 스타일 (펜 종류에 따라)
  TextStyle _getTextStyle() {
    Color textColor = Colors.black;
    FontWeight fontWeight = FontWeight.normal;
    double fontSize = 14;

    // 펜 종류에 따른 스타일
    switch (_selectedPenType) {
      case '볼펜':
        textColor = Colors.black;
        fontWeight = FontWeight.normal;
        break;
      case '싸인펜':
        textColor = Colors.blue.shade700;
        fontWeight = FontWeight.w500;
        break;
      case '형광펜':
        textColor = Colors.black;
        fontWeight = FontWeight.bold;
        break;
    }

    // 글씨체에 따른 폰트 패밀리 (실제로는 폰트 파일이 필요하지만 여기서는 스타일만 변경)
    String? fontFamily;
    switch (_selectedFontFamily) {
      case '고딕':
        fontWeight = FontWeight.w600;
        break;
      case '명조':
        fontWeight = FontWeight.w300;
        break;
      case '손글씨':
        fontWeight = FontWeight.w400;
        break;
      case '둥근':
        fontWeight = FontWeight.w400;
        break;
    }

    return TextStyle(
      color: textColor,
      fontWeight: fontWeight,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );
  }
}

