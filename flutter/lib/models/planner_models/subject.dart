// lib/models/planner_models/subject.dart
// 과목 모델 (학점계산기용)

/// 과목 모델
class Subject {
  final String id;
  final String name;
  final double credits;
  final String grade; // A+, A, B+, B, C+, C, D+, D, F
  final double gradePoint;
  final int year; // 학년 (1, 2, 3, 4)
  final int semester; // 학기 (1, 2)

  Subject({
    required this.id,
    required this.name,
    required this.credits,
    required this.grade,
    required this.year,
    required this.semester,
  }) : gradePoint = _getGradePoint(grade) * credits;

  static double _getGradePoint(String grade) {
    switch (grade) {
      case 'A+':
        return 4.5;
      case 'A':
        return 4.0;
      case 'B+':
        return 3.5;
      case 'B':
        return 3.0;
      case 'C+':
        return 2.5;
      case 'C':
        return 2.0;
      case 'D+':
        return 1.5;
      case 'D':
        return 1.0;
      case 'F':
        return 0.0;
      default:
        return 0.0;
    }
  }

  // JSON으로 변환 (저장용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'credits': credits,
      'grade': grade,
      'year': year,
      'semester': semester,
    };
  }

  // JSON에서 생성
  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String,
      credits: (json['credits'] as num).toDouble(),
      grade: json['grade'] as String,
      year: json['year'] as int,
      semester: json['semester'] as int,
    );
  }

  // 복사 생성자 (수정용)
  Subject copyWith({
    String? id,
    String? name,
    double? credits,
    String? grade,
    int? year,
    int? semester,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      credits: credits ?? this.credits,
      grade: grade ?? this.grade,
      year: year ?? this.year,
      semester: semester ?? this.semester,
    );
  }
}
