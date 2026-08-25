import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/service_requests/data/customer_service_case_repository.dart';

void main() {
  test('parses backend lifecycle without inventing required documents', () {
    final detail = CustomerServiceCaseDetail.fromResponse({
      'message': {
        'case': {
          'name': 'SR-001',
          'title': 'NTN Registration',
          'request_state': 'Payment Not Required',
          'status': 'Open',
          'display_status': 'Ready for Activation',
          'required_documents_count': 0,
          'document_details': <Map<String, dynamic>>[],
          'receipt': {
            'status': 'Not Required',
            'payment_status': 'Not Required',
          },
          'settlement': {
            'status': 'Not Required',
            'payable_amount': 0,
            'currency': 'PKR',
          },
          'customer_lifecycle': {
            'current_stage': 'Ready for processing',
            'progress_percent': 60,
            'action_required': false,
            'terminal': false,
            'completed': false,
            'payment_not_required': true,
            'next_action': {
              'type': 'view_service',
              'title': 'Track service progress',
              'subtitle': 'No new customer action is required right now.',
              'route': '/my-services/SR-001',
              'button_label': 'View progress',
              'required': false,
            },
            'milestones': [
              {
                'key': 'documents',
                'label': 'Documents',
                'state': 'skipped',
                'detail': 'No documents are currently required.',
              },
              {
                'key': 'payment',
                'label': 'Payment',
                'state': 'skipped',
                'detail': 'No payment is required for this request.',
              },
            ],
          },
          'recent_activity': <Map<String, dynamic>>[],
        },
      },
    });

    expect(detail.id, 'SR-001');
    expect(detail.currentStage, 'Ready for processing');
    expect(detail.paymentNotRequired, isTrue);
    expect(detail.requiredDocuments, isEmpty);
    expect(detail.documentsNeedingUpload, 0);
    expect(detail.milestones, hasLength(2));
    expect(detail.milestones[0].isSkipped, isTrue);
    expect(detail.milestones[1].isSkipped, isTrue);
    expect(detail.nextAction?.required, isFalse);
    expect(detail.activities, isEmpty);
  });

  test(
    'uses backend payment review action and does not infer a second payment',
    () {
      final detail = CustomerServiceCaseDetail.fromResponse({
        'case': {
          'name': 'SR-002',
          'request_state': 'Pending Payment',
          'status': 'Waiting for Payment',
          'receipt': {
            'status': 'Submitted',
            'payment_status': 'Receipt Submitted',
            'payment_id': 'PAY-002',
          },
          'settlement': {'status': 'Unmatched'},
          'customer_lifecycle': {
            'current_stage': 'Payment review',
            'progress_percent': 50,
            'action_required': false,
            'terminal': false,
            'completed': false,
            'payment_not_required': false,
            'next_action': {
              'type': 'await_payment_review',
              'title': 'Payment under review',
              'subtitle': 'OMC is reviewing your submitted payment evidence.',
              'route': '/payments',
              'button_label': 'View payment',
              'required': false,
            },
            'milestones': <Map<String, dynamic>>[],
          },
        },
      });

      expect(detail.paymentUnderReview, isTrue);
      expect(detail.paymentNeedsCorrection, isFalse);
      expect(detail.actionRequired, isFalse);
      expect(detail.nextAction?.type, 'await_payment_review');
      expect(detail.paymentId, 'PAY-002');
    },
  );

  test('keeps document instructions and backend-required status', () {
    final detail = CustomerServiceCaseDetail.fromResponse({
      'case': {
        'name': 'SR-003',
        'request_state': 'Draft',
        'status': 'Waiting for Customer',
        'document_details': [
          {
            'id': '-',
            'document_key': 'bank_statement',
            'title': 'Bank statement',
            'document_type': 'Financial',
            'status': 'Pending',
            'remarks': 'Upload the latest three months.',
            'file_url': '',
            'is_required': 1,
          },
          {
            'id': 'DOC-2',
            'title': 'Optional note',
            'status': 'Uploaded',
            'file_url': '/private/files/note.pdf',
            'is_required': 0,
          },
        ],
        'customer_lifecycle': {
          'current_stage': 'Documents',
          'progress_percent': 25,
          'action_required': true,
          'terminal': false,
          'completed': false,
          'payment_not_required': false,
          'next_action': {
            'type': 'upload_document',
            'title': 'Documents need your attention',
            'route': '/documents',
            'button_label': 'Open documents',
            'required': true,
          },
          'milestones': <Map<String, dynamic>>[],
        },
      },
    });

    expect(detail.requiredDocuments, hasLength(1));
    expect(detail.requiredDocuments.single.title, 'Bank statement');
    expect(detail.requiredDocuments.single.documentKey, 'bank_statement');
    expect(detail.requiredDocuments.single.documentType, 'Financial');
    expect(
      detail.requiredDocuments.single.uploadIdentity,
      'key:bank_statement',
    );
    expect(
      detail.requiredDocuments.single.remarks,
      'Upload the latest three months.',
    );
    expect(detail.documentsNeedingUpload, 1);
    expect(detail.nextAction?.required, isTrue);
  });

  test('parses only backend-provided real recent activity', () {
    final detail = CustomerServiceCaseDetail.fromResponse({
      'case': {
        'name': 'SR-004',
        'customer_lifecycle': {
          'current_stage': 'OMC processing',
          'progress_percent': 85,
          'action_required': false,
          'terminal': false,
          'completed': false,
          'payment_not_required': false,
          'milestones': <Map<String, dynamic>>[],
        },
        'recent_activity': [
          {
            'title': 'Consultant requested clarification',
            'description': 'Please confirm the filing year.',
            'event_time': '20 Aug 2026, 1:15 AM',
          },
        ],
      },
    });

    expect(detail.activities, hasLength(1));
    expect(
      detail.activities.single.title,
      'Consultant requested clarification',
    );
    expect(
      detail.activities.single.subtitle,
      'Please confirm the filing year.',
    );
  });
}
