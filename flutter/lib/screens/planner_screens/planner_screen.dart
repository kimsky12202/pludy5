// lib/screens/planner_screens/planner_screens.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../models/planner_models/planner_models.dart';
import '../../../services/planner_services/planner_services.dart';
import './schedule_dialog.dart';
import './goal_dialog.dart';
import './timetable_schedule_dialog.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 캘린더, 시간표, 목표달성, 학점계산기 탭
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('학습 플래너'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today), text: '캘린더'),
            Tab(icon: Icon(Icons.schedule), text: '시간표'),
            Tab(icon: Icon(Icons.flag), text: '목표달성'),
            Tab(icon: Icon(Icons.calculate), text: '학점계산기'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const CalendarView(), // 캘린더 화면
          const TimetableView(), // 시간표 화면
          const GoalView(), // 목표달성 화면
          const GradeCalculatorView(), // 학점계산기 화면
        ],
      ),
    );
  }
}

// 캘린더 화면
class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  List<Schedule> _schedules = [];
  Map<DateTime, List<Schedule>> _allSchedulesMap = {};

  @override
  void initState() {
    super.initState();
    _loadAllSchedules();
    _loadSchedules();
  }

  /// 모든 일정 로드 (캘린더에 표시용)
  Future<void> _loadAllSchedules() async {
    final allSchedules = await ScheduleService.getAllSchedules();
    final Map<DateTime, List<Schedule>> scheduleMap = {};

    for (var schedule in allSchedules) {
      final date = DateTime(
        schedule.date.year,
        schedule.date.month,
        schedule.date.day,
      );
      scheduleMap.putIfAbsent(date, () => []).add(schedule);
    }

    if (mounted) {
      setState(() {
        _allSchedulesMap = scheduleMap;
      });
    }
  }

  /// 일정 로드
  Future<void> _loadSchedules() async {
    final schedules = await ScheduleService.getSchedulesForDate(_selectedDay);
    if (mounted) {
      setState(() {
        _schedules = schedules;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 캘린더 위젯
        TableCalendar<Schedule>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: (day) {
            final date = DateTime(day.year, day.month, day.day);
            return _allSchedulesMap[date] ?? [];
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            // 선택한 날짜의 일정 로드
            _loadSchedules();
          },
          calendarFormat: CalendarFormat.month,
          startingDayOfWeek: StartingDayOfWeek.monday,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarStyle: CalendarStyle(
            markerDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isNotEmpty) {
                return Positioned(
                  bottom: 1,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }
              return null;
            },
          ),
        ),
        const Divider(),
        // 선택한 날짜의 일정 목록
        Expanded(child: _buildScheduleList()),
      ],
    );
  }

  // 선택한 날짜의 일정 목록 표시
  Widget _buildScheduleList() {
    return Column(
      children: [
        // 헤더와 추가 버튼
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedDay.year}년 ${_selectedDay.month}월 ${_selectedDay.day}일 일정',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              FloatingActionButton.small(
                onPressed: () => _showAddScheduleDialog(),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        const Divider(),
        // 일정 목록
        Expanded(
          child:
              _schedules.isEmpty
                  ? const Center(
                    child: Text(
                      '일정이 없습니다.\n+ 버튼을 눌러 일정을 추가하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _schedules.length,
                    itemBuilder: (context, index) {
                      return _buildScheduleItem(_schedules[index]);
                    },
                  ),
        ),
      ],
    );
  }

  // 일정 아이템 위젯
  Widget _buildScheduleItem(Schedule schedule) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: schedule.isCompleted,
          onChanged: (value) async {
            await ScheduleService.toggleScheduleCompletion(schedule.id);
            _loadSchedules();
          },
        ),
        title: Text(
          schedule.title,
          style: TextStyle(
            decoration:
                schedule.isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (schedule.description != null &&
                schedule.description!.isNotEmpty)
              Text(schedule.description!),
            if (schedule.startTime != null)
              Text(
                '${schedule.startTime!.hour.toString().padLeft(2, '0')}:${schedule.startTime!.minute.toString().padLeft(2, '0')}'
                '${schedule.endTime != null ? ' - ${schedule.endTime!.hour.toString().padLeft(2, '0')}:${schedule.endTime!.minute.toString().padLeft(2, '0')}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditScheduleDialog(schedule),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteSchedule(schedule.id),
            ),
          ],
        ),
      ),
    );
  }

  // 일정 추가 다이얼로그
  Future<void> _showAddScheduleDialog() async {
    final result = await showDialog<Schedule>(
      context: context,
      builder: (context) => ScheduleDialog(date: _selectedDay),
    );

    if (result != null) {
      await ScheduleService.saveSchedule(result);
      _loadAllSchedules(); // 전체 일정 맵 업데이트
      _loadSchedules(); // 선택한 날짜의 일정 업데이트
    }
  }

  // 일정 수정 다이얼로그
  Future<void> _showEditScheduleDialog(Schedule schedule) async {
    final result = await showDialog<Schedule>(
      context: context,
      builder:
          (context) => ScheduleDialog(date: schedule.date, schedule: schedule),
    );

    if (result != null) {
      await ScheduleService.saveSchedule(result);
      _loadAllSchedules(); // 전체 일정 맵 업데이트
      _loadSchedules(); // 선택한 날짜의 일정 업데이트
    }
  }

  // 일정 삭제
  Future<void> _deleteSchedule(String scheduleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('일정 삭제'),
            content: const Text('정말 이 일정을 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await ScheduleService.deleteSchedule(scheduleId);
      _loadAllSchedules(); // 전체 일정 맵 업데이트
      _loadSchedules(); // 선택한 날짜의 일정 업데이트
    }
  }
}

// 시간표 화면
class TimetableView extends StatefulWidget {
  const TimetableView({super.key});

  @override
  State<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends State<TimetableView> {
  // 현재 주의 시작일 (월요일)
  DateTime _weekStart = _getWeekStart(DateTime.now());
  Map<DateTime, List<Schedule>> _weekSchedules = {};

  @override
  void initState() {
    super.initState();
    _loadWeekSchedules();
  }

  /// 주의 시작일 계산 (월요일)
  static DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday; // 1=월요일, 7=일요일
    return date.subtract(Duration(days: weekday - 1));
  }

  /// 주의 끝일 계산 (일요일)
  static DateTime _getWeekEnd(DateTime weekStart) {
    return weekStart.add(const Duration(days: 6));
  }

  /// 주간 일정 로드
  Future<void> _loadWeekSchedules() async {
    final allSchedules = await ScheduleService.getAllSchedules();
    final Map<DateTime, List<Schedule>> scheduleMap = {};

    // 현재 주의 일정만 필터링
    final weekEnd = _getWeekEnd(_weekStart);
    for (var schedule in allSchedules) {
      final scheduleDate = DateTime(
        schedule.date.year,
        schedule.date.month,
        schedule.date.day,
      );

      // 현재 주 범위 내인지 확인
      if (scheduleDate.isAfter(_weekStart.subtract(const Duration(days: 1))) &&
          scheduleDate.isBefore(weekEnd.add(const Duration(days: 1)))) {
        scheduleMap.putIfAbsent(scheduleDate, () => []).add(schedule);
      }
    }

    if (mounted) {
      setState(() {
        _weekSchedules = scheduleMap;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 주간 선택 바
        _buildWeekSelector(),
        const Divider(),
        // 시간표
        Expanded(child: _buildTimetable()),
      ],
    );
  }

  // 시간표 텍스트 스타일
  TextStyle _getTimetableTextStyle() {
    return const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: Colors.black,
    );
  }

  // 주간 선택 바
  Widget _buildWeekSelector() {
    final weekEnd = _getWeekEnd(_weekStart);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _weekStart = _weekStart.subtract(const Duration(days: 7));
              });
              _loadWeekSchedules();
            },
          ),
          Text(
            '${_weekStart.year}년 ${_weekStart.month}월 ${_weekStart.day}일 ~ '
            '${weekEnd.month}월 ${weekEnd.day}일',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _weekStart = _weekStart.add(const Duration(days: 7));
              });
              _loadWeekSchedules();
            },
          ),
        ],
      ),
    );
  }

  // 시간표 위젯
  Widget _buildTimetable() {
    final weekDays = List.generate(
      7,
      (index) => _weekStart.add(Duration(days: index)),
    );

    return Column(
      children: [
        // 요일 헤더
        _buildDayHeaders(weekDays),
        const Divider(),
        // 시간표 본문 - 시간 표시와 요일별 박스
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 시간 표시 컬럼
              _buildTimeColumn(),
              // 요일별 박스들
              Expanded(
                child: Row(
                  children:
                      weekDays.map((date) {
                        return Expanded(child: _buildDayBox(date));
                      }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 요일 헤더
  Widget _buildDayHeaders(List<DateTime> weekDays) {
    final dayNames = ['월', '화', '수', '목', '금', '토', '일'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 60), // 시간 컬럼 공간
          ...weekDays.asMap().entries.map((entry) {
            final index = entry.key;
            final date = entry.value;
            return Expanded(
              child: Column(
                children: [
                  Text(
                    dayNames[index],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          date.day == DateTime.now().day &&
                                  date.month == DateTime.now().month &&
                                  date.year == DateTime.now().year
                              ? Colors.blue
                              : Colors.black,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 시간 표시 컬럼 (00:00 ~ 23:00)
  Widget _buildTimeColumn() {
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: List.generate(24, (index) {
          return Expanded(
            child: Center(
              child: Text(
                '${index.toString().padLeft(2, '0')}:00',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // 요일별 큰 박스
  Widget _buildDayBox(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final schedules = _weekSchedules[dateKey] ?? [];

    return InkWell(
      onTap: () {
        // 박스 클릭 시 일정 추가/수정
        if (schedules.isEmpty) {
          _showAddScheduleForDay(date);
        } else {
          _showSchedulesForDay(schedules, date);
        }
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boxHeight = constraints.maxHeight;

            return Stack(
              children: [
                // 시간대별 구분선
                ...List.generate(24, (index) {
                  return Positioned(
                    top: (index / 24) * boxHeight,
                    left: 0,
                    right: 0,
                    child: Container(height: 1, color: Colors.grey.shade200),
                  );
                }),
                // 일정 표시
                ...schedules.map((schedule) {
                  if (schedule.startTime == null || schedule.endTime == null) {
                    return const SizedBox.shrink();
                  }

                  final startMinutes =
                      schedule.startTime!.hour * 60 +
                      schedule.startTime!.minute;
                  final endMinutes =
                      schedule.endTime!.hour * 60 + schedule.endTime!.minute;
                  final startPosition = (startMinutes / (24 * 60)) * boxHeight;
                  final endPosition = (endMinutes / (24 * 60)) * boxHeight;
                  final height = endPosition - startPosition;

                  return Positioned(
                    top: startPosition,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: height,
                      decoration: BoxDecoration(
                        color:
                            schedule.isCompleted
                                ? (schedule.color ?? Colors.grey).withOpacity(
                                  0.4,
                                )
                                : (schedule.color ?? Colors.blue).withOpacity(
                                  0.6,
                                ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Text(
                          schedule.title,
                          style: _getTimetableTextStyle().copyWith(
                            fontSize: 9,
                            color: Colors.white, // 배경색에 맞춰 흰색 유지
                            decoration:
                                schedule.isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  // 요일 박스에 일정 추가
  Future<void> _showAddScheduleForDay(DateTime date) async {
    final result = await showDialog<Schedule>(
      context: context,
      builder:
          (context) => TimetableScheduleDialog(
            date: date,
            initialHour: 9,
            initialMinute: 0,
          ),
    );

    if (result != null) {
      await ScheduleService.saveSchedule(result);
      _loadWeekSchedules();
    }
  }

  // 요일의 일정 목록 표시
  void _showSchedulesForDay(List<Schedule> schedules, DateTime date) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date.year}년 ${date.month}월 ${date.day}일 일정',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      final schedule = schedules[index];
                      return ListTile(
                        leading: Checkbox(
                          value: schedule.isCompleted,
                          onChanged: (value) async {
                            await ScheduleService.toggleScheduleCompletion(
                              schedule.id,
                            );
                            _loadWeekSchedules();
                            Navigator.of(context).pop();
                          },
                        ),
                        title: Text(schedule.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (schedule.description != null)
                              Text(schedule.description!),
                            if (schedule.startTime != null &&
                                schedule.endTime != null)
                              Text(
                                '${schedule.startTime!.hour.toString().padLeft(2, '0')}:${schedule.startTime!.minute.toString().padLeft(2, '0')} ~ '
                                '${schedule.endTime!.hour.toString().padLeft(2, '0')}:${schedule.endTime!.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: schedule.color ?? Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: schedule.color ?? Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                final result = await showDialog<Schedule>(
                                  context: context,
                                  builder:
                                      (context) => TimetableScheduleDialog(
                                        date: schedule.date,
                                        initialHour:
                                            schedule.startTime?.hour ?? 0,
                                        initialMinute:
                                            schedule.startTime?.minute ?? 0,
                                        schedule: schedule,
                                      ),
                                );
                                if (result != null) {
                                  await ScheduleService.saveSchedule(result);
                                  _loadWeekSchedules();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await ScheduleService.deleteSchedule(
                                  schedule.id,
                                );
                                _loadWeekSchedules();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showAddScheduleForDay(date);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('일정 추가'),
                ),
              ],
            ),
          ),
    );
  }
}

// 목표달성 화면
class GoalView extends StatefulWidget {
  const GoalView({super.key});

  @override
  State<GoalView> createState() => _GoalViewState();
}

class _GoalViewState extends State<GoalView> {
  List<Goal> _goals = [];

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  /// 목표 로드
  Future<void> _loadGoals() async {
    final goals = await GoalService.getAllGoals();
    if (mounted) {
      setState(() {
        _goals = goals;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 헤더와 추가 버튼
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '목표달성',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              FloatingActionButton.small(
                onPressed: () => _showAddGoalDialog(),
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        const Divider(),
        // 목표 목록
        Expanded(
          child:
              _goals.isEmpty
                  ? const Center(
                    child: Text(
                      '목표가 없습니다.\n+ 버튼을 눌러 목표를 추가하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _goals.length,
                    itemBuilder: (context, index) {
                      return _buildGoalItem(_goals[index]);
                    },
                  ),
        ),
      ],
    );
  }

  // 목표 아이템 위젯
  Widget _buildGoalItem(Goal goal) {
    final timeRemaining = goal.timeRemaining;
    final isOverdue = goal.isOverdue;
    final isCompleted = goal.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color:
          isOverdue && !isCompleted
              ? Colors.red.shade50
              : isCompleted
              ? Colors.grey.shade100
              : Colors.white,
      child: ListTile(
        leading: Checkbox(
          value: goal.isCompleted,
          onChanged: (value) async {
            await GoalService.toggleGoalCompletion(goal.id);
            _loadGoals();
          },
        ),
        title: Text(
          goal.title,
          style: TextStyle(
            decoration:
                isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
            fontWeight:
                isOverdue && !isCompleted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (goal.description != null && goal.description!.isNotEmpty)
              Text(goal.description!),
            const SizedBox(height: 4),
            Text(
              '마감: ${DateFormat('yyyy년 MM월 dd일 HH:mm').format(goal.deadline)}',
              style: TextStyle(
                fontSize: 12,
                color:
                    isOverdue && !isCompleted
                        ? Colors.red
                        : Colors.grey.shade600,
              ),
            ),
            if (!isCompleted && !isOverdue)
              Text(
                _formatTimeRemaining(timeRemaining),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (isOverdue && !isCompleted)
              const Text(
                '⚠️ 마감일이 지났습니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditGoalDialog(goal),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteGoal(goal.id),
            ),
          ],
        ),
      ),
    );
  }

  // 남은 시간 포맷팅
  String _formatTimeRemaining(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}일 ${duration.inHours % 24}시간 남음';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}시간 ${duration.inMinutes % 60}분 남음';
    } else {
      return '${duration.inMinutes}분 남음';
    }
  }

  // 목표 추가 다이얼로그
  Future<void> _showAddGoalDialog() async {
    final result = await showDialog<Goal>(
      context: context,
      builder: (context) => const GoalDialog(),
    );

    if (result != null) {
      await GoalService.saveGoal(result);
      _loadGoals();
    }
  }

  // 목표 수정 다이얼로그
  Future<void> _showEditGoalDialog(Goal goal) async {
    final result = await showDialog<Goal>(
      context: context,
      builder: (context) => GoalDialog(goal: goal),
    );

    if (result != null) {
      await GoalService.saveGoal(result);
      _loadGoals();
    }
  }

  // 목표 삭제
  Future<void> _deleteGoal(String goalId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('목표 삭제'),
            content: const Text('정말 이 목표를 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await GoalService.deleteGoal(goalId);
      _loadGoals();
    }
  }
}

// 학점계산기 화면
class GradeCalculatorView extends StatefulWidget {
  const GradeCalculatorView({super.key});

  @override
  State<GradeCalculatorView> createState() => _GradeCalculatorViewState();
}

class _GradeCalculatorViewState extends State<GradeCalculatorView> {
  final Map<String, List<Subject>> _subjectsBySemester = {}; // 학기별 과목 저장
  String? _selectedSemester; // 현재 선택된 학기
  double _totalCredits = 0.0;
  double _totalGradePoints = 0.0;
  double _gpa = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  // 과목 로드 (SharedPreferences에서)
  Future<void> _loadSubjects() async {
    // TODO: SharedPreferences에서 로드
    setState(() {
      if (_subjectsBySemester.isEmpty) {
        // 기본 학기 추가
        _addSemester(1, 1);
      }
    });
    _calculateGPA();
  }

  // 과목 저장 (SharedPreferences에)
  Future<void> _saveSubjects() async {
    // TODO: SharedPreferences에 저장
  }

  // 학기 추가
  void _addSemester(int year, int semester) {
    final key = '$year-$semester';
    if (!_subjectsBySemester.containsKey(key)) {
      setState(() {
        _subjectsBySemester[key] = [];
        _selectedSemester = key;
      });
      _saveSubjects();
    }
  }

  // 학기 삭제
  void _deleteSemester(String semesterKey) {
    setState(() {
      _subjectsBySemester.remove(semesterKey);
      if (_selectedSemester == semesterKey) {
        _selectedSemester =
            _subjectsBySemester.keys.isNotEmpty
                ? _subjectsBySemester.keys.first
                : null;
      }
    });
    _saveSubjects();
    _calculateGPA();
  }

  // 학기 키를 표시 이름으로 변환
  String _getSemesterDisplayName(String key) {
    final parts = key.split('-');
    return '${parts[0]}학년 ${parts[1]}학기';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 결과 표시 영역
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard('총 학점', _totalCredits.toStringAsFixed(1)),
                  _buildStatCard('평균 학점', _gpa.toStringAsFixed(2)),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        // 학기 선택 및 추가 버튼
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedSemester,
                  hint: const Text('학기 선택'),
                  isExpanded: true,
                  items:
                      _subjectsBySemester.keys.map((key) {
                        return DropdownMenuItem(
                          value: key,
                          child: Text(_getSemesterDisplayName(key)),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSemester = value;
                    });
                    _calculateGPA();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddSemesterDialog(),
                tooltip: '학기 추가',
              ),
              if (_selectedSemester != null)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed:
                      () => _showDeleteSemesterDialog(_selectedSemester!),
                  tooltip: '학기 삭제',
                ),
            ],
          ),
        ),
        const Divider(),
        // 헤더와 과목 추가 버튼
        if (_selectedSemester != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_getSemesterDisplayName(_selectedSemester!)} 과목 목록',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FloatingActionButton.small(
                  onPressed: () => _showAddSubjectDialog(),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        const Divider(),
        // 과목 목록
        Expanded(
          child:
              _selectedSemester == null
                  ? const Center(
                    child: Text(
                      '학기를 선택하거나 추가하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : _subjectsBySemester[_selectedSemester!]!.isEmpty
                  ? const Center(
                    child: Text(
                      '과목이 없습니다.\n+ 버튼을 눌러 과목을 추가하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _subjectsBySemester[_selectedSemester!]!.length,
                    itemBuilder: (context, index) {
                      return _buildSubjectItem(
                        _subjectsBySemester[_selectedSemester!]![index],
                        index,
                      );
                    },
                  ),
        ),
      ],
    );
  }

  // 통계 카드
  Widget _buildStatCard(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  // 과목 아이템
  Widget _buildSubjectItem(Subject subject, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(subject.name),
        subtitle: Text('학점: ${subject.credits} | 성적: ${subject.grade}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${subject.gradePoint.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditSubjectDialog(subject, index),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteSubject(index),
            ),
          ],
        ),
      ),
    );
  }

  // GPA 계산 (모든 학기 합산)
  void _calculateGPA() {
    _totalCredits = 0.0;
    _totalGradePoints = 0.0;

    for (var subjects in _subjectsBySemester.values) {
      for (var subject in subjects) {
        _totalCredits += subject.credits;
        _totalGradePoints += subject.gradePoint;
      }
    }

    _gpa = _totalCredits > 0 ? _totalGradePoints / _totalCredits : 0.0;

    setState(() {});
  }

  // 학기 추가 다이얼로그
  Future<void> _showAddSemesterDialog() async {
    int? selectedYear = 1;
    int? selectedSemester = 1;

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('학기 추가'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedYear,
                      decoration: const InputDecoration(
                        labelText: '학년',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          List.generate(4, (index) => index + 1).map((year) {
                            return DropdownMenuItem(
                              value: year,
                              child: Text('$year학년'),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedYear = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedSemester,
                      decoration: const InputDecoration(
                        labelText: '학기',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          [1, 2].map((semester) {
                            return DropdownMenuItem(
                              value: semester,
                              child: Text('$semester학기'),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSemester = value;
                        });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('취소'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (selectedYear != null && selectedSemester != null) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    child: const Text('추가'),
                  ),
                ],
              );
            },
          ),
    );

    if (result == true && selectedYear != null && selectedSemester != null) {
      _addSemester(selectedYear!, selectedSemester!);
    }
  }

  // 학기 삭제 확인 다이얼로그
  Future<void> _showDeleteSemesterDialog(String semesterKey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('학기 삭제'),
            content: Text(
              '${_getSemesterDisplayName(semesterKey)}의 모든 과목이 삭제됩니다.\n정말 삭제하시겠습니까?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      _deleteSemester(semesterKey);
    }
  }

  // 과목 추가 다이얼로그
  Future<void> _showAddSubjectDialog() async {
    if (_selectedSemester == null) return;

    final parts = _selectedSemester!.split('-');
    final year = int.parse(parts[0]);
    final semester = int.parse(parts[1]);

    final result = await showDialog<Subject>(
      context: context,
      builder: (context) => SubjectDialog(year: year, semester: semester),
    );

    if (result != null) {
      setState(() {
        _subjectsBySemester[_selectedSemester!]!.add(result);
      });
      _saveSubjects();
      _calculateGPA();
    }
  }

  // 과목 수정 다이얼로그
  Future<void> _showEditSubjectDialog(Subject subject, int index) async {
    if (_selectedSemester == null) return;

    final result = await showDialog<Subject>(
      context: context,
      builder: (context) => SubjectDialog(subject: subject),
    );

    if (result != null) {
      setState(() {
        _subjectsBySemester[_selectedSemester!]![index] = result;
      });
      _saveSubjects();
      _calculateGPA();
    }
  }

  // 과목 삭제
  void _deleteSubject(int index) {
    if (_selectedSemester == null) return;

    setState(() {
      _subjectsBySemester[_selectedSemester!]!.removeAt(index);
    });
    _saveSubjects();
    _calculateGPA();
  }
}

// 과목 추가/수정 다이얼로그
class SubjectDialog extends StatefulWidget {
  final Subject? subject;
  final int? year; // 새 과목 추가 시 학년
  final int? semester; // 새 과목 추가 시 학기

  const SubjectDialog({super.key, this.subject, this.year, this.semester});

  @override
  State<SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<SubjectDialog> {
  final _nameController = TextEditingController();
  final _creditsController = TextEditingController();
  String _selectedGrade = 'A+';
  int? _selectedYear;
  int? _selectedSemester;

  final List<String> _grades = [
    'A+',
    'A',
    'B+',
    'B',
    'C+',
    'C',
    'D+',
    'D',
    'F',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.subject != null) {
      _nameController.text = widget.subject!.name;
      _creditsController.text = widget.subject!.credits.toString();
      _selectedGrade = widget.subject!.grade;
      _selectedYear = widget.subject!.year;
      _selectedSemester = widget.subject!.semester;
    } else {
      _selectedYear = widget.year;
      _selectedSemester = widget.semester;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.subject == null ? '과목 추가' : '과목 수정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '과목명 *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _creditsController,
            decoration: const InputDecoration(
              labelText: '학점 *',
              border: OutlineInputBorder(),
              hintText: '예: 3',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          if (widget.subject == null) ...[
            DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: const InputDecoration(
                labelText: '학년',
                border: OutlineInputBorder(),
              ),
              items:
                  List.generate(4, (index) => index + 1).map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text('$year학년'),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedYear = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedSemester,
              decoration: const InputDecoration(
                labelText: '학기',
                border: OutlineInputBorder(),
              ),
              items:
                  [1, 2].map((semester) {
                    return DropdownMenuItem(
                      value: semester,
                      child: Text('$semester학기'),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSemester = value;
                });
              },
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<String>(
            value: _selectedGrade,
            decoration: const InputDecoration(
              labelText: '성적',
              border: OutlineInputBorder(),
            ),
            items:
                _grades.map((grade) {
                  return DropdownMenuItem(value: grade, child: Text(grade));
                }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedGrade = value;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(onPressed: _saveSubject, child: const Text('저장')),
      ],
    );
  }

  void _saveSubject() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('과목명을 입력해주세요')));
      return;
    }

    final credits = double.tryParse(_creditsController.text);
    if (credits == null || credits <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('올바른 학점을 입력해주세요')));
      return;
    }

    if (_selectedYear == null || _selectedSemester == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('학년과 학기를 선택해주세요')));
      return;
    }

    if (_selectedYear == null || _selectedSemester == null) {
      return;
    }

    final subject = Subject(
      id:
          widget.subject?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      credits: credits,
      grade: _selectedGrade,
      year: _selectedYear!,
      semester: _selectedSemester!,
    );

    Navigator.of(context).pop(subject);
  }
}
