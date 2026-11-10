class AiInsight {
  final String id;
  final String title;
  final String type; // 'trend', 'alert', 'top_product', 'dead_stock', 'action_tip'
  final String description;
  final String urduTranslation;
  final String severity; // 'critical', 'warning', 'positive', 'info'
  final double? metricValue;
  final String? metricLabel;
  final DateTime createdAt;

  const AiInsight({
    required this.id,
    required this.title,
    required this.type,
    required this.description,
    required this.urduTranslation,
    this.severity = 'info',
    this.metricValue,
    this.metricLabel,
    required this.createdAt,
  });

  factory AiInsight.fromJson(Map<String, dynamic> json) {
    return AiInsight(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'info',
      description: json['description']?.toString() ?? '',
      urduTranslation: json['urdu_translation']?.toString() ?? json['urduTranslation']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'info',
      metricValue: json['metric_value'] != null
          ? double.tryParse(json['metric_value'].toString())
          : (json['metricValue'] != null ? double.tryParse(json['metricValue'].toString()) : null),
      metricLabel: json['metric_label']?.toString() ?? json['metricLabel']?.toString(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'description': description,
      'urdu_translation': urduTranslation,
      'severity': severity,
      'metric_value': metricValue,
      'metric_label': metricLabel,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
