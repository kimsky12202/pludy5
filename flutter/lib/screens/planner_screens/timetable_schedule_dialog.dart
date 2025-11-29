// lib/screens/planner_screens/timetable_schedule_dialog.dart
// 시간표에서 시간 범위와 색상을 선택하는 다이얼로그
import 'package:flutter/material.dart';
import '../../models/planner_models/planner_models.dart';
import 'dart:math';

class TimetableScheduleDialog extends StatefulWidget {
  final DateTime date;
  final int initialHour; // 클릭한 시간 (0-23)
  final int initialMinute; // 클릭한 분 (0 또는 30)
  final Schedule? schedule; // 수정 모드일 때 기존 일정

  const TimetableScheduleDialog({
    super.key,
    required this.date,
    required this.initialHour,
    this.initialMinute = 0,
    this.schedule,
  });

  @override
  State<TimetableScheduleDialog> createState() => _TimetableScheduleDialogState();
}

class _TimetableScheduleDialogState extends State<TimetableScheduleDialog> {
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
    } else {
      // 새 일정일 때 클릭한 시간을 시작 시간으로 설정
      _startTime = TimeOfDay(hour: widget.initialHour, minute: widget.initialMinute);
      // 기본 종료 시간은 1시간 후
      final endHour = (widget.initialHour + 1) % 24;
      _endTime = TimeOfDay(hour: endHour, minute: widget.initialMinute);
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
                    // 종료 시간이 시작 시간보다 이전이면 종료 시간도 업데이트
                    if (_endTime != null) {
                      final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
                      final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
                      if (endMinutes <= startMinutes) {
                        _endTime = TimeOfDay(
                          hour: (_startTime!.hour + 1) % 24,
                          minute: _startTime!.minute,
                        );
                      }
                    }
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
        ElevatedButton(
          onPressed: _saveSchedule,
          child: const Text('저장'),
        ),
      ],
    );
  }

  void _saveSchedule() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요')),
      );
      return;
    }

    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작 시간과 종료 시간을 선택해주세요')),
      );
      return;
    }

    // 종료 시간이 시작 시간보다 이전이면 오류
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료 시간은 시작 시간보다 늦어야 합니다')),
      );
      return;
    }

    final schedule = Schedule(
      id: widget.schedule?.id ?? _generateId(),
      date: widget.date,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
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

