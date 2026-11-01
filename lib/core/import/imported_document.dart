import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'question_parser.dart';

/// Versioned, loss-minimizing representation of an imported source document.
/// Raw page content stays beside interpreted records for future reparsing.
class ImportedDocument {
  ImportedDocument({
    String? id,
    this.schemaVersion = 1,
    this.metadata = const {},
    required this.pages,
    this.sections = const [],
    this.supportingMaterials = const [],
    required this.questions,
    this.qualityNotices = const [],
  }) : id = id ?? _documentId(pages);

  final String id;
  final int schemaVersion;
  final Map<String, Object?> metadata;
  final List<ImportedDocumentPage> pages;
  final List<ImportedSection> sections;
  final List<SupportingMaterial> supportingMaterials;
  final List<ImportedQuestion> questions;
  final List<String> qualityNotices;

  ImportedDocument copyWith({List<ImportedQuestion>? questions}) =>
      ImportedDocument(
        id: id,
        schemaVersion: schemaVersion,
        metadata: metadata,
        pages: pages,
        sections: sections,
        supportingMaterials: supportingMaterials
            .where(
              (material) =>
                  material.questionId == null ||
                  (questions ?? this.questions).any(
                    (question) => question.id == material.questionId,
                  ),
            )
            .toList(growable: false),
        questions: questions ?? this.questions,
        qualityNotices: qualityNotices,
      );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'metadata': metadata,
    'pages': pages.map((page) => page.toJson()).toList(),
    'sections': sections.map((section) => section.toJson()).toList(),
    'supportingMaterials': supportingMaterials
        .map((material) => material.toJson())
        .toList(),
    'questions': questions
        .asMap()
        .entries
        .map((entry) => entry.value.toJson(entry.key))
        .toList(),
    'qualityNotices': qualityNotices,
  };

  factory ImportedDocument.fromJson(Map<String, dynamic> json) =>
      ImportedDocument(
        id: json['id'] as String?,
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
        metadata: Map<String, Object?>.from(
          json['metadata'] as Map? ?? const {},
        ),
        pages: (json['pages'] as List? ?? const [])
            .map(
              (page) => ImportedDocumentPage.fromJson(
                Map<String, dynamic>.from(page as Map),
              ),
            )
            .toList(),
        sections: (json['sections'] as List? ?? const [])
            .map(
              (section) => ImportedSection.fromJson(
                Map<String, dynamic>.from(section as Map),
              ),
            )
            .toList(),
        supportingMaterials: (json['supportingMaterials'] as List? ?? const [])
            .map(
              (material) => SupportingMaterial.fromJson(
                Map<String, dynamic>.from(material as Map),
              ),
            )
            .toList(),
        questions: (json['questions'] as List? ?? const [])
            .map(
              (question) => ImportedQuestion.fromJson(
                Map<String, dynamic>.from(question as Map),
              ),
            )
            .toList(),
        qualityNotices: List<String>.from(
          json['qualityNotices'] as List? ?? const [],
        ),
      );
}

String _documentId(List<ImportedDocumentPage> pages) =>
    'doc-${sha256.convert(utf8.encode(pages.map((page) => page.text).join('\n')))}';

class ImportedDocumentPage {
  const ImportedDocumentPage({
    required this.number,
    required this.text,
    this.mediaAssetId,
    this.mediaObjectKey,
    this.mediaMimeType,
    this.mediaSha256,
    this.mediaAltText,
    this.nativeText = '',
    this.source = 'unknown',
    this.regions = const [],
    this.previewBytes,
    this.warning,
  });

  final int number;
  final String text;
  final String? mediaAssetId;
  final String? mediaObjectKey;
  final String? mediaMimeType;
  final String? mediaSha256;
  final String? mediaAltText;
  final String nativeText;
  final String source;
  final List<Map<String, Object?>> regions;
  final Uint8List? previewBytes;
  final String? warning;

  Map<String, Object?> toJson() => {
    'number': number,
    'text': text,
    'mediaAssetId': mediaAssetId,
    'mediaObjectKey': mediaObjectKey,
    'mediaMimeType': mediaMimeType,
    'mediaSha256': mediaSha256,
    'mediaAltText': mediaAltText,
    'nativeText': nativeText,
    'source': source,
    'regions': regions,
    if (previewBytes != null) 'previewBase64': base64Encode(previewBytes!),
    'warning': warning,
  };

  factory ImportedDocumentPage.fromJson(Map<String, dynamic> json) =>
      ImportedDocumentPage(
        number: (json['number'] as num?)?.toInt() ?? 0,
        text: json['text'] as String? ?? '',
        mediaAssetId: json['mediaAssetId'] as String?,
        mediaObjectKey: json['mediaObjectKey'] as String?,
        mediaMimeType: json['mediaMimeType'] as String?,
        mediaSha256: json['mediaSha256'] as String?,
        mediaAltText: json['mediaAltText'] as String?,
        nativeText: json['nativeText'] as String? ?? '',
        source: json['source'] as String? ?? 'unknown',
        regions: (json['regions'] as List? ?? const [])
            .map((region) => Map<String, Object?>.from(region as Map))
            .toList(),
        previewBytes: json['previewBase64'] is String
            ? base64Decode(json['previewBase64'] as String)
            : null,
        warning: json['warning'] as String?,
      );
}

class ImportedSection {
  const ImportedSection({
    required this.id,
    required this.title,
    this.subject,
    this.area,
    this.language,
    this.firstPage,
    this.lastPage,
    this.order = 0,
    this.questionIds = const [],
  });

  final String id;
  final String title;
  final String? subject;
  final String? area;
  final String? language;
  final int? firstPage;
  final int? lastPage;
  final int order;
  final List<String> questionIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'area': area,
    'language': language,
    'firstPage': firstPage,
    'lastPage': lastPage,
    'order': order,
    'questionIds': questionIds,
  };

  factory ImportedSection.fromJson(Map<String, dynamic> json) =>
      ImportedSection(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        subject: json['subject'] as String?,
        area: json['area'] as String?,
        language: json['language'] as String?,
        firstPage: (json['firstPage'] as num?)?.toInt(),
        lastPage: (json['lastPage'] as num?)?.toInt(),
        order: (json['order'] as num?)?.toInt() ?? 0,
        questionIds: List<String>.from(
          json['questionIds'] as List? ?? const [],
        ),
      );
}

class SupportingMaterial {
  const SupportingMaterial({
    required this.id,
    required this.type,
    this.questionId,
    this.text,
    this.page,
    this.caption,
    this.sourcePosition,
    this.confidence,
    this.raw = const {},
  });

  final String id;
  final String type;
  final String? questionId;
  final String? text;
  final int? page;
  final String? caption;
  final int? sourcePosition;
  final double? confidence;
  final Map<String, Object?> raw;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'questionId': questionId,
    'text': text,
    'page': page,
    'caption': caption,
    'sourcePosition': sourcePosition,
    'confidence': confidence,
    'raw': raw,
  };

  factory SupportingMaterial.fromJson(Map<String, dynamic> json) =>
      SupportingMaterial(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'unknown',
        questionId: json['questionId'] as String?,
        text: json['text'] as String?,
        page: (json['page'] as num?)?.toInt(),
        caption: json['caption'] as String?,
        sourcePosition: (json['sourcePosition'] as num?)?.toInt(),
        confidence: (json['confidence'] as num?)?.toDouble(),
        raw: Map<String, Object?>.from(json['raw'] as Map? ?? const {}),
      );
}

/// Gives each visually uncertain question a stable media identity while
/// keeping its compressed source-page preview stored once on the page record.
List<SupportingMaterial> associateQuestionVisualSources(
  List<ImportedQuestion> questions,
) {
  final materials = <SupportingMaterial>[];
  for (final question in questions) {
    if (question.warning?.contains('conteúdo visual não foi extraído') !=
        true) {
      continue;
    }
    final mediaId = 'question-visual-${question.id}';
    if (!question.supportingMaterialIds.contains(mediaId)) {
      question.supportingMaterialIds.add(mediaId);
    }
    materials.add(
      SupportingMaterial(
        id: mediaId,
        type: 'questionImageSource',
        questionId: question.id,
        page: question.sourcePage,
        caption: 'Imagem original da questão ${question.number ?? ''}'.trim(),
        raw: {'sourcePages': question.sourcePages},
      ),
    );
  }
  return List.unmodifiable(materials);
}
