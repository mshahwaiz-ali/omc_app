import 'package:flutter/material.dart';

class ServiceCase {
  const ServiceCase({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.createdAtLabel,
    required this.updatedAtLabel,
    required this.progress,
    this.reference,
    this.nextStep,
    this.remarks,
    this.requiredDocuments = const [],
    this.submittedDocuments = const [],
    this.missingDocuments = const [],
    this.timeline = const [],
  });

  final String id;
  final String title;
  final String category;
  final String status;
  final String createdAtLabel;
  final String updatedAtLabel;
  final double progress;
  final String? reference;
  final String? nextStep;
  final String? remarks;
  final List<String> requiredDocuments;
  final List<String> submittedDocuments;
  final List<String> missingDocuments;
  final List<ServiceCaseTimelineStep> timeline;
}

class ServiceCaseTimelineStep {
  const ServiceCaseTimelineStep({
    required this.title,
    required this.subtitle,
    required this.isDone,
  });

  final String title;
  final String subtitle;
  final bool isDone;
}

class ServiceCaseStatusStyle {
  const ServiceCaseStatusStyle({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
