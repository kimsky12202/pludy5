// lib/screens/planner_screens/schedule_dialog.dart
// 일정 추가/수정 다이얼로그
import 'package:flutter/material.dart';
import '../../models/planner_models/planner_models.dart';
import 'dart:math';

class ScheduleDialog extends StatefulWidget {
  final DateTime date;
  final Schedule? schedule; // 수정 모드일 때 기존 일정
  final int? initialHour; // 시간표에서 호출 시 초기 시간 설정

  const ScheduleDialog({
    super.key,
    required this.date,
    this.schedule,
    this.initialHour,
  });

  @override
  State<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  Color _selectedColor = Colors.blue;

  // 기본 색상 목록
  final List<Color> _colorOptions = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    // 수정 모드일 때 기존 값 설정
    if (widget.schedule != null) {
      _titleController.text = widget.schedule!.title;
      _descriptionController.text = widget.schedule!.description ?? '';
      _startTime = widget.schedule!.startTime;
      _endTime = widget.schedule!.endTime;
      _selectedColor = widget.schedule!.color ?? Colors.blue;
    } else if (widget.initialHour != null) {
      // 시간표에서 호출 시 초기 시간 설정
      _startTime = TimeOfDay(hour: widget.initialHour!, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.schedule == null ? '일정 추가' : '일정 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 날짜 표시
            Text(
              '${widget.date.year}년 ${widget.date.month}월 ${widget.date.day}일',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            // 제목 입력
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목 *',
                border: OutlineInputBorder(),
                hintText: '일정 제목을 입력하세요',
              ),
            ),
            const SizedBox(height: 16),
            // 설명 입력
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '설명',
                border: OutlineInputBorder(),
                hintText: '일정 설명을 입력하세요 (선택사항)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // 시작 시간 선택
            ListTile(
              title: const Text('시작 시간'),
              trailing: Text(
                _startTime != null
                    ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                    : '선택 안함',
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _startTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    _startTime = time;
                  });
                }
              },
            ),
            // 종료 시간 선택
            ListTile(
              title: const Text('종료 시간'),
              trailing: Text(
                _endTime != null
                    ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                    : '선택 안함',
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() {
                    _endTime = time;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            // 색상 선택
            const Text(
              '색상 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colorOptions.map((color) {
                final isSelected = color.value == _selectedColor.value;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(onPressed: _saveSchedule, child: const Text('저장')),
      ],
    );
  }

  void _saveSchedule() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목을 입력해주세요')));
      return;
    }

    final schedule = Schedule(
      id: widget.schedule?.id ?? _generateId(),
      date: widget.date,
      title: _titleController.text.trim(),
      description:
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
      startTime: _startTime,
      endTime: _endTime,
      isCompleted: widget.schedule?.isCompleted ?? false,
      color: _selectedColor,
    );

    Navigator.of(context).pop(schedule);
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(1000).toString();
  }
}
