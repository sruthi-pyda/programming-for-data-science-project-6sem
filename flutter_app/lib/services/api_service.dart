import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;

class PredictionResult {
  final String riskLevel;
  final String riskColor;
  final double probLow;
  final double probMedium;
  final double probHigh;

  PredictionResult({
    required this.riskLevel,
    required this.riskColor,
    required this.probLow,
    required this.probMedium,
    required this.probHigh,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    // R/Plumber returns single-row data frames as arrays — unwrap them
    T unwrap<T>(dynamic v) => (v is List ? v.first : v) as T;

    final prob = json['probability'] as Map<String, dynamic>;
    return PredictionResult(
      riskLevel: unwrap<String>(json['risk_level']),
      riskColor: unwrap<String>(json['risk_color']),
      probLow: (unwrap<num>(prob['Low'])).toDouble(),
      probMedium: (unwrap<num>(prob['Medium'])).toDouble(),
      probHigh: (unwrap<num>(prob['High'])).toDouble(),
    );
  }
}

class AreaRisk {
  final String areaName;
  final int totalAccidents;
  final double avgSeverity;
  final double compositeScore;

  AreaRisk({
    required this.areaName,
    required this.totalAccidents,
    required this.avgSeverity,
    required this.compositeScore,
  });

  factory AreaRisk.fromJson(Map<String, dynamic> json) => AreaRisk(
        areaName: json['area_name'] as String,
        totalAccidents: (json['total_accidents'] as num).toInt(),
        avgSeverity: (json['avg_severity'] as num).toDouble(),
        compositeScore: (json['composite_score'] as num).toDouble(),
      );
}

class ApiService {
  static const String _baseUrl = 'http://localhost:8000';

  Future<PredictionResult> predict({
    required int area,
    required int hour,
    required int monthNum,
    required int premisCd,
    double avgVictimAge = 35,
    double avgSeverity = 2,
  }) async {
    final uri = Uri.parse('$_baseUrl/predict').replace(queryParameters: {
      'area': area.toString(),
      'hour': hour.toString(),
      'month_num': monthNum.toString(),
      'premis_cd': premisCd.toString(),
      'avg_victim_age': avgVictimAge.toString(),
      'avg_severity': avgSeverity.toString(),
    });

    dev.log('[API] GET $uri', name: 'ApiService');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      dev.log('[API] status=${response.statusCode} body=${response.body}', name: 'ApiService');

      if (response.statusCode == 200) {
        return PredictionResult.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('API error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      dev.log('[API] FAILED: $e', name: 'ApiService', level: 1000);
      rethrow;
    }
  }

  Future<List<AreaRisk>> getAreaRankings({int top = 10}) async {
    final uri = Uri.parse('$_baseUrl/areas/ranking')
        .replace(queryParameters: {'top': top.toString()});
    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final names = (data['area_name'] as List).cast<String>();
      final totals = (data['total_accidents'] as List).map((e) => (e as num).toInt()).toList();
      final severities = (data['avg_severity'] as List).map((e) => (e as num).toDouble()).toList();
      final scores = (data['composite_score'] as List).map((e) => (e as num).toDouble()).toList();

      return List.generate(names.length, (i) => AreaRisk(
        areaName: names[i],
        totalAccidents: totals[i],
        avgSeverity: severities[i],
        compositeScore: scores[i],
      ));
    } else {
      throw Exception('API error ${response.statusCode}');
    }
  }
}
