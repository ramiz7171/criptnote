import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

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

  static String _getToneInstruction(String tone) {
    switch (tone) {
      case 'casual': return 'Write in a friendly, casual tone.';
      case 'concise': return 'Be extremely concise and to the point.';
      case 'detailed': return 'Provide detailed, comprehensive responses.';
      default: return 'Write in a professional, formal tone.';
    }
  }
}
