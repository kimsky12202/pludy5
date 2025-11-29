// lib/screens/planner_screens/goal_dialog.dart
// 목표 추가/수정 다이얼로그
import 'package:flutter/material.dart';
import '../../models/planner_models/planner_models.dart';
import 'dart:math';

class GoalDialog extends StatefulWidget {
  final Goal? goal; // 수정 모드일 때 기존 목표

  const GoalDialog({
    super.key,
    this.goal,
  });

  @override
  State<GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<GoalDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    // 수정 모드일 때 기존 값 설정
    if (widget.goal != null) {
      _titleController.text = widget.goal!.title;
      _descriptionController.text = widget.goal!.description ?? '';
      _selectedDate = widget.goal!.deadline;
      _selectedTime = TimeOfDay(
        hour: widget.goal!.deadline.hour,
        minute: widget.goal!.deadline.minute,
      );
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
      title: Text(widget.goal == null ? '목표 추가' : '목표 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목 입력
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '목표 제목 *',
                border: OutlineInputBorder(),
                hintText: '목표를 입력하세요',
              ),
            ),
            const SizedBox(height: 16),
            // 설명 입력
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '설명',
                border: OutlineInputBorder(),
                hintText: '목표 설명을 입력하세요 (선택사항)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // 날짜 선택
            ListTile(
              title: const Text('마감 날짜'),
              trailing: Text(
                '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
            ),
            // 시간 선택
            ListTile(
              title: const Text('마감 시간'),
              trailing: Text(
                '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (time != null) {
                  setState(() {
                    _selectedTime = time;
                  });
                }
              },
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
          onPressed: _saveGoal,
          child: const Text('저장'),
        ),
      ],
    );
  }

  void _saveGoal() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요')),
      );
      return;
    }

    // 날짜와 시간을 합쳐서 deadline 생성
    final deadline = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final goal = Goal(
      id: widget.goal?.id ?? _generateId(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      deadline: deadline,
      isCompleted: widget.goal?.isCompleted ?? false,
      createdAt: widget.goal?.createdAt,
    );

    Navigator.of(context).pop(goal);
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(1000).toString();
  }
}

