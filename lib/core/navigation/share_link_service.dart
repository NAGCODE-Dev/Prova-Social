class ShareLinkDestination {
  const ShareLinkDestination({required this.examId, this.questionId});

  final String examId;
  final String? questionId;
}

class ShareLinkService {
  static const host = 'prova-social.pages.dev';

  static Uri exam(String examId) => Uri.https(host, '/provas/$examId');

  static Uri question(String examId, String questionId) =>
      Uri.https(host, '/provas/$examId/questoes/$questionId');

  static ShareLinkDestination? parse(String? route) {
    if (route == null || route.isEmpty) return null;
    final uri = Uri.tryParse(route);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    if (segments.length < 2 || segments.first != 'provas') return null;
    final examId = segments[1];
    if (!_isUuid(examId)) return null;
    if (segments.length == 2) return ShareLinkDestination(examId: examId);
    if (segments.length == 4 &&
        segments[2] == 'questoes' &&
        _isUuid(segments[3])) {
      return ShareLinkDestination(examId: examId, questionId: segments[3]);
    }
    return null;
  }

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
