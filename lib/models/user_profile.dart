class UserProfile {
  final String name;
  final String idNo;
  final double basic;
  final double allowance;
  final double rate;
  final String email;

  UserProfile({
    required this.name,
    required this.idNo,
    required this.basic,
    required this.allowance,
    required this.rate,
    required this.email,
  });

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) => UserProfile(
    name:      map['name']      ?? '',
    idNo:      map['idNo']      ?? '',
    basic:     (map['basic']      ?? 0).toDouble(),
    allowance: (map['allowance']  ?? 0).toDouble(),
    rate:      (map['rate']       ?? 0).toDouble(),
    email:     map['email']     ?? '',
  );

  Map<String, dynamic> toMap() => {
    'name': name, 'idNo': idNo,
    'basic': basic, 'allowance': allowance,
    'rate': rate, 'email': email,
  };

  double get otEarning => 0; // calculated with hours
  double totalSalary(double otHours) => basic + allowance + (otHours * rate);
}
