class UserProfile {
  final String name;
  final String idNo;
  final double basic;
  final double allowance;
  final double rate;
  final String email;
  final String? photoUrl;

  UserProfile({
    required this.name,
    required this.idNo,
    required this.basic,
    required this.allowance,
    required this.rate,
    required this.email,
    this.photoUrl,
  });

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) => UserProfile(
        name: map['name']?.toString() ?? '',
        idNo: map['idNo']?.toString() ?? '',
        basic: _toDouble(map['basic']),
        allowance: _toDouble(map['allowance']),
        rate: _toDouble(map['rate']),
        email: map['email']?.toString() ?? '',
        // Additive field: older Firebase profiles simply have no photoUrl.
        photoUrl: map['photoUrl']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'idNo': idNo,
        'basic': basic,
        'allowance': allowance,
        'rate': rate,
        'email': email,
        'photoUrl': photoUrl,
      };

  UserProfile copyWith({
    String? name,
    String? idNo,
    double? basic,
    double? allowance,
    double? rate,
    String? email,
    String? photoUrl,
  }) {
    return UserProfile(
      name: name ?? this.name,
      idNo: idNo ?? this.idNo,
      basic: basic ?? this.basic,
      allowance: allowance ?? this.allowance,
      rate: rate ?? this.rate,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  double get otEarning => 0;
  double totalSalary(double otHours) => basic + allowance + (otHours * rate);
}
