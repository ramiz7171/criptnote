const GEMINI_API_KEY = import.meta.env.VITE_GEMINI_API_KEY
const GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'

// Runtime check — this value is baked in at BUILD time by Vite
export const AI_KEY_CONFIGURED = !!GEMINI_API_KEY
if (!GEMINI_API_KEY) {
  console.warn('[CriptNote AI] VITE_GEMINI_API_KEY is not set — AI features will not work. Was the env var set during the Vercel build?')
}

async function callGemini(prompt: string): Promise<string> {
  if (!GEMINI_API_KEY) {
    throw new Error('AI API key is not configured. Check environment variables.')
  }
  console.log('[CriptNote AI] Calling Gemini API...')
  const res = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
    }),
  })

  if (!res.ok) {
    const err = await res.text()
    throw new Error(`Gemini API error: ${res.status} ${err}`)
  }

  const data = await res.json()
  const result = data?.candidates?.[0]?.content?.parts?.[0]?.text
  if (!result) throw new Error('No response returned from Gemini')
  return result
}

export async function summarizeText(text: string): Promise<string> {
  return callGemini(`Summarize the following note concisely in a few sentences:\n\n${text}`)
}

export async function fixGrammar(text: string): Promise<string> {
  return callGemini(
    `Fix the grammar, spelling, and punctuation of the following text. Return ONLY the corrected text, no explanations or extra commentary:\n\n${text}`
  )
}

export async function fixCode(code: string, language: string): Promise<string> {
  return callGemini(
    `Fix bugs, errors, and issues in the following ${language} code. Return ONLY the corrected code, no explanations, no markdown fences, no commentary:\n\n${code}`
  )
}

// ── Daily usage limits ──
export const AI_LIMITS = {
  summarize: { daily: 2, maxChars: 10_000 },
  grammar: { daily: 2, maxChars: 5_000 },
  codefix: { daily: 2 },
  transcript: { daily: 2 },
  meeting_notes: { daily: 2 },
  action_items: { daily: 2 },
  ai_writer: { daily: 2, maxChars: 5_000 },
} as const

function todayKey(feature: string, userId: string): string {
  return `criptnote-${feature}-${userId}-${new Date().getFullYear()}`
}

export function getDailyUsage(feature: string, userId: string, limit: number): { used: number; remaining: number } {
  const stored = localStorage.getItem(todayKey(feature, userId))
  const used = stored ? parseInt(stored, 10) : 0
  return { used, remaining: Math.max(0, limit - used) }
}

export function addDailyUsage(feature: string, userId: string, amount: number): void {
  const stored = localStorage.getItem(todayKey(feature, userId))
  const used = stored ? parseInt(stored, 10) : 0
  localStorage.setItem(todayKey(feature, userId), String(used + amount))
}

// Backward-compatible aliases for code fix
export function getCodeFixUsage(userId: string) { return getDailyUsage('codefix', userId, AI_LIMITS.codefix.daily) }
export function addCodeFixUsage(userId: string) { addDailyUsage('codefix', userId, 1) }

function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onloadend = () => {
      const dataUrl = reader.result as string
      resolve(dataUrl.split(',')[1])
    }
    reader.onerror = reject
    reader.readAsDataURL(blob)
  })
}

export async function transcribeAudio(audioBlob: Blob): Promise<string> {
  const base64 = await blobToBase64(audioBlob)

  const res = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{
        parts: [
          { inline_data: { mime_type: audioBlob.type, data: base64 } },
          { text: 'Transcribe this audio recording accurately. Return ONLY the transcribed text, no explanations or extra commentary.' },
        ],
      }],
    }),
  })

  if (!res.ok) {
    const err = await res.text()
    throw new Error(`Gemini API error: ${res.status} ${err}`)
  }

  const data = await res.json()
  const result = data?.candidates?.[0]?.content?.parts?.[0]?.text
  if (!result) throw new Error('No transcription returned from Gemini')
  return result
}

export async function transcribeWithSpeakers(audioBlob: Blob): Promise<{
  transcript: string
  segments: { speaker: string; text: string }[]
}> {
  const base64 = await blobToBase64(audioBlob)
  const res = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{
        parts: [
          { inline_data: { mime_type: audioBlob.type, data: base64 } },
          { text: `Transcribe this audio recording with speaker identification.
Return a JSON object with this exact structure:
{"transcript": "Full transcription as plain text", "segments": [{"speaker": "Speaker 1", "text": "What they said"}, {"speaker": "Speaker 2", "text": "What they said"}]}
If only one speaker, use "Speaker 1". Return ONLY the JSON, no markdown fences.` },
        ],
      }],
    }),
  })
  if (!res.ok) { const err = await res.text(); throw new Error(`Gemini API error: ${res.status} ${err}`) }
  const data = await res.json()
  const result = data?.candidates?.[0]?.content?.parts?.[0]?.text
  if (!result) throw new Error('No transcription returned from Gemini')
  try {
    const cleaned = result.replace(/```json\n?/g, '').replace(/```\n?/g, '').trim()
    return JSON.parse(cleaned)
  } catch {
    return { transcript: result, segments: [{ speaker: 'Speaker 1', text: result }] }
  }
}

export async function generateTranscriptSummary(text: string, tone = 'professional', length = 'medium'): Promise<string> {
  const count = length === 'short' ? '3-5' : length === 'long' ? '10-15' : '5-8'
  return callGemini(`Summarize the following transcript as ${count} concise bullet points in a ${tone} tone. Use markdown bullet format (- ).\n\nTranscript:\n${text}`)
}

export async function extractActionItems(text: string): Promise<string> {
  return callGemini(`Extract all action items, tasks, decisions, and follow-ups from this transcript. Format each as a markdown checkbox:\n- [ ] Action item description (assigned to: Person, if mentioned)\n\nIf no clear action items exist, respond with "No action items identified."\n\nTranscript:\n${text}`)
}

export async function generateMeetingNotes(text: string, agenda: string[] = []): Promise<string> {
  const agendaSection = agenda.length > 0 ? `\nAgenda items: ${agenda.join(', ')}\n` : ''
  return callGemini(`Generate structured meeting notes from this transcript.${agendaSection}\n\nFormat:\n## Key Discussion Points\n- Point 1\n\n## Decisions Made\n- Decision 1\n\n## Action Items\n- [ ] Action 1\n\n## Next Steps\n- Step 1\n\nTranscript:\n${text}`)
}

export async function generateEmail(subject: string, context: string, tone: string): Promise<string> {
  return callGemini(`Write a ${tone} email about the following subject.\n\nSubject: ${subject}\nContext/Details: ${context}\n\nInclude a subject line, greeting, body, and sign-off. Return only the email text.`)
}

export async function generateMessage(context: string, tone: string): Promise<string> {
  return callGemini(`Write a ${tone} message based on the following context.\n\nContext: ${context}\n\nKeep it appropriate for the tone. Return only the message text.`)
}

export async function generateFollowUp(title: string, participants: string[], notes: string, tone = 'professional'): Promise<string> {
  return callGemini(`Generate a ${tone} follow-up email for a meeting.\n\nMeeting: ${title}\nParticipants: ${participants.join(', ')}\n\nContent:\n${notes}\n\nFormat as a complete email with subject line, greeting, meeting recap, key decisions, action items with owners, next steps, and sign-off. Return ONLY the email text.`)
}
