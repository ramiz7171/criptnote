import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static Future<String?> generate({
    required String prompt,
    String tone = 'professional',
  }) async {
    final url = Uri.parse('$_baseUrl?key=${AppConstants.geminiApiKey}');
    final systemPrompt = _getToneInstruction(tone);

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': '$systemPrompt\n\n$prompt'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      }
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
        return text;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  static Future<String?> summarize(String content, {String length = 'medium'}) async {
    final lengthInstruction = {
      'short': 'in 1-2 sentences',
      'medium': 'in 3-5 sentences',
      'long': 'in detail with bullet points',
    }[length] ?? 'in 3-5 sentences';
    return generate(prompt: 'Summarize the following content $lengthInstruction:\n\n$content');
  }

  static Future<String?> checkGrammar(String content) async {
    return generate(
      prompt: 'Check and correct the grammar in the following text. Return only the corrected text:\n\n$content',
    );
  }

  static Future<String?> generateMeetingNotes(String meetingData) async {
    return generate(
      prompt: 'Generate professional meeting notes from the following information:\n\n$meetingData',
    );
  }

  static Future<String?> summarizeTranscript(String transcript) async {
    return generate(
      prompt: 'Summarize the following transcript and extract key action items:\n\n$transcript',
    );
  }

  static Future<Map<String, dynamic>?> transcribeAudio(Uint8List audioBytes, String mimeType) async {
    final url = Uri.parse('$_baseUrl?key=${AppConstants.geminiApiKey}');
    final b64 = base64Encode(audioBytes);

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': b64,
              }
            },
            {
              'text': 'Transcribe this audio accurately. Then provide:\n1. TRANSCRIPT: the full verbatim transcription\n2. SUMMARY: a concise 2-3 sentence summary\n3. ACTION_ITEMS: list of action items if any (or "None")\nFormat your response exactly as:\nTRANSCRIPT:\n[text]\n\nSUMMARY:\n[text]\n\nACTION_ITEMS:\n[text]'
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 4096,
      }
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '';
        return _parseTranscription(text);
      }
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic> _parseTranscription(String text) {
    String transcript = text;
    String summary = '';
    String actionItems = '';

    final tIdx = text.indexOf('TRANSCRIPT:');
    final sIdx = text.indexOf('SUMMARY:');
    final aIdx = text.indexOf('ACTION_ITEMS:');

    if (tIdx >= 0) {
      final end = sIdx >= 0 ? sIdx : (aIdx >= 0 ? aIdx : text.length);
      transcript = text.substring(tIdx + 11, end).trim();
    }
    if (sIdx >= 0) {
      final end = aIdx >= 0 ? aIdx : text.length;
      summary = text.substring(sIdx + 8, end).trim();
    }
    if (aIdx >= 0) {
      actionItems = text.substring(aIdx + 13).trim();
    }

    return {'transcript': transcript, 'summary': summary, 'actionItems': actionItems};
  }

  static Future<String?> fixCode(String code, String language) async {
    return generate(
      prompt: 'Review and fix any bugs or issues in this $language code. Return only the corrected code:\n\n```$language\n$code\n```',
    );
  }

  static String _getToneInstruction(String tone) {
    switch (tone) {
      case 'casual': return 'Write in a friendly, casual tone.';
      case 'concise': return 'Be extremely concise and to the point.';
      case 'detailed': return 'Provide detailed, comprehensive responses.';
      default: return 'Write in a professional, formal tone.';
    }
  }
}
