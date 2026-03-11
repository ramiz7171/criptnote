import { useState, useEffect, useRef, useCallback } from 'react'
import { createPortal } from 'react-dom'
import TagInput from '../shared/TagInput'
import StatusBadge from '../shared/StatusBadge'
import CustomSelect from '../shared/CustomSelect'
import { useAuth } from '../../context/AuthContext'
import { useTranscriptVoiceRecorder } from '../../hooks/useTranscriptVoiceRecorder'
import { useSettings } from '../../hooks/useSettings'
import {
  generateMeetingNotes,
  generateFollowUp,
  transcribeWithSpeakers,
  getDailyUsage,
  addDailyUsage,
  AI_LIMITS,
} from '../../lib/gemini'
import type { Meeting, MeetingStatus, AgendaItem } from '../../types'

interface MeetingDetailModalProps {
  meeting: Meeting
  onUpdate: (id: string, updates: Partial<Meeting>) => Promise<{ error?: unknown } | undefined>
  onDelete: (id: string) => Promise<void>
  onClose: () => void
}

const STATUS_OPTIONS: { value: MeetingStatus; label: string }[] = [
  { value: 'scheduled', label: 'Scheduled' },
  { value: 'in_progress', label: 'In Progress' },
  { value: 'completed', label: 'Completed' },
  { value: 'cancelled', label: 'Cancelled' },
]

function toLocalDatetimeString(iso: string): string {
  const d = new Date(iso)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

export default function MeetingDetailModal({ meeting, onUpdate, onDelete, onClose }: MeetingDetailModalProps) {
  const { user, profile } = useAuth()
  const { settings } = useSettings()
  const recorder = useTranscriptVoiceRecorder()
  const backdropRef = useRef<HTMLDivElement>(null)

  // Local editable state
  const [title, setTitle] = useState(meeting.title)
  const [meetingDate, setMeetingDate] = useState(toLocalDatetimeString(meeting.meeting_date))
  const [status, setStatus] = useState<MeetingStatus>(meeting.status)
  const [duration, setDuration] = useState(meeting.duration_minutes)
  const [participants, setParticipants] = useState<string[]>(meeting.participants || [])
  const [tags, setTags] = useState<string[]>(meeting.tags || [])
  const [agenda, setAgenda] = useState<AgendaItem[]>(meeting.agenda || [])
  const [newAgendaText, setNewAgendaText] = useState('')

  // AI content
  const [aiNotes, setAiNotes] = useState(meeting.ai_notes)
  const [followUp, setFollowUp] = useState(meeting.follow_up)
  const [generatingNotes, setGeneratingNotes] = useState(false)
  const [generatingFollowUp, setGeneratingFollowUp] = useState(false)
  const [aiError, setAiError] = useState('')

  // Recording
  const [recordingSeconds, setRecordingSeconds] = useState(0)
  const [transcribing, setTranscribing] = useState(false)
  const [transcriptText, setTranscriptText] = useState('')
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  // Delete confirmation
  const [confirmDelete, setConfirmDelete] = useState(false)

  // Close animation
  const [closing, setClosing] = useState(false)

  const animateClose = useCallback(() => {
    if (closing) return
    setClosing(true)
    setTimeout(onClose, 200)
  }, [onClose, closing])

  // Escape key
  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') animateClose()
    }
    document.addEventListener('keydown', handleEsc)
    return () => document.removeEventListener('keydown', handleEsc)
  }, [animateClose])

  // Recording timer
  useEffect(() => {
    if (recorder.recording) {
      setRecordingSeconds(0)
      timerRef.current = setInterval(() => {
        setRecordingSeconds(prev => prev + 1)
      }, 1000)
    } else {
      if (timerRef.current) {
        clearInterval(timerRef.current)
        timerRef.current = null
      }
    }
    return () => {
      if (timerRef.current) clearInterval(timerRef.current)
    }
  }, [recorder.recording])

  // Auto-transcribe when recording stops and blob is available
  useEffect(() => {
    if (!recorder.recording && recorder.audioBlob && !transcribing) {
      handleTranscribe()
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [recorder.recording, recorder.audioBlob])

  // ── Save helpers ──

  const save = (updates: Partial<Meeting>) => {
    onUpdate(meeting.id, updates)
  }

  const handleTitleBlur = () => {
    if (title.trim() !== meeting.title) save({ title: title.trim() })
  }

  const handleDateChange = (val: string) => {
    setMeetingDate(val)
    save({ meeting_date: new Date(val).toISOString() })
  }

  const handleStatusChange = (val: MeetingStatus) => {
    setStatus(val)
    save({ status: val })
  }

  const handleDurationBlur = () => {
    if (duration !== meeting.duration_minutes) save({ duration_minutes: duration })
  }

  const handleParticipantsChange = (val: string[]) => {
    setParticipants(val)
    save({ participants: val })
  }

  const handleTagsChange = (val: string[]) => {
    setTags(val)
    save({ tags: val })
  }

  // Agenda
  const handleToggleAgendaItem = (index: number) => {
    const updated = agenda.map((item, i) =>
      i === index ? { ...item, completed: !item.completed } : item
    )
    setAgenda(updated)
    save({ agenda: updated })
  }

  const handleAddAgendaItem = () => {
    if (!newAgendaText.trim()) return
    const updated = [...agenda, { text: newAgendaText.trim(), completed: false }]
    setAgenda(updated)
    setNewAgendaText('')
    save({ agenda: updated })
  }

  const handleRemoveAgendaItem = (index: number) => {
    const updated = agenda.filter((_, i) => i !== index)
    setAgenda(updated)
    save({ agenda: updated })
  }

  // ── AI features ──

  const isAdmin = profile?.is_admin ?? false

  const handleGenerateNotes = async () => {
    if (!user) return
    setAiError('')

    // Check daily limit (admin bypass)
    if (!isAdmin) {
      const { remaining } = getDailyUsage('meeting_notes', user.id, AI_LIMITS.meeting_notes.daily)
      if (remaining <= 0) {
        setAiError('✨ Premium coming soon — upgrade for unlimited AI')
        return
      }
    }

    // Need some source text
    const sourceText = transcriptText || aiNotes
    if (!sourceText && !meeting.transcript_id) {
      setAiError('Record or link a transcript to generate AI notes.')
      return
    }

    setGeneratingNotes(true)
    try {
      const agendaTexts = agenda.map(a => a.text)
      const notes = await generateMeetingNotes(sourceText || 'No transcript text available.', agendaTexts)
      setAiNotes(notes)
      save({ ai_notes: notes })
      if (!isAdmin) addDailyUsage('meeting_notes', user.id, 1)
    } catch (err) {
      setAiError(err instanceof Error ? err.message : 'Failed to generate notes.')
    } finally {
      setGeneratingNotes(false)
    }
  }

  const handleGenerateFollowUp = async () => {
    if (!user) return
    setAiError('')

    if (!isAdmin) {
      const { remaining } = getDailyUsage('meeting_notes', user.id, AI_LIMITS.meeting_notes.daily)
      if (remaining <= 0) {
        setAiError('✨ Premium coming soon — upgrade for unlimited AI')
        return
      }
    }

    const notesText = aiNotes || transcriptText
    if (!notesText) {
      setAiError('Generate meeting notes first, or record a transcript.')
      return
    }

    setGeneratingFollowUp(true)
    try {
      const email = await generateFollowUp(title, participants, notesText, settings?.ai_tone || 'professional')
      setFollowUp(email)
      save({ follow_up: email })
      if (!isAdmin) addDailyUsage('meeting_notes', user.id, 1)
    } catch (err) {
      setAiError(err instanceof Error ? err.message : 'Failed to generate follow-up.')
    } finally {
      setGeneratingFollowUp(false)
    }
  }

  // ── Recording & transcription ──

  const handleStartRecording = async () => {
    try {
      await recorder.startRecording()
    } catch {
      setAiError('Could not access microphone. Check browser permissions.')
    }
  }

  const handleStopRecording = () => {
    recorder.stopRecording()
  }

  const handleTranscribe = async () => {
    if (!recorder.audioBlob || !user) return
    setTranscribing(true)
    setAiError('')

    // Check transcript limit
    if (!isAdmin) {
      const { remaining } = getDailyUsage('transcript', user.id, AI_LIMITS.transcript.daily)
      if (remaining <= 0) {
        setAiError('✨ Premium coming soon — upgrade for unlimited AI')
        setTranscribing(false)
        return
      }
    }

    try {
      // Upload audio
      const url = await recorder.uploadAudio()
      if (url) save({ audio_url: url })

      // Transcribe
      const result = await transcribeWithSpeakers(recorder.audioBlob)
      setTranscriptText(result.transcript)
      if (!isAdmin) addDailyUsage('transcript', user.id, 1)
    } catch (err) {
      setAiError(err instanceof Error ? err.message : 'Transcription failed.')
    } finally {
      setTranscribing(false)
      recorder.reset()
    }
  }

  // ── Delete ──

  const handleDelete = async () => {
    await onDelete(meeting.id)
    animateClose()
  }

  const formatTimer = (s: number) => {
    const m = Math.floor(s / 60)
    const sec = s % 60
    return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
  }

  return createPortal(
    <div
      ref={backdropRef}
      onClick={(e) => { if (e.target === backdropRef.current) animateClose() }}
      className={`fixed inset-0 z-[9998] flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm transition-opacity duration-200 ${
        closing ? 'opacity-0' : 'animate-[fadeIn_0.15s_ease-out]'
      }`}
    >
      <div
        onClick={e => e.stopPropagation()}
        className={`w-full max-w-4xl max-h-[90vh] glass-panel-solid rounded-2xl shadow-2xl border border-gray-200/50 dark:border-white/5 flex flex-col transition-all duration-200 ${
          closing ? 'opacity-0 scale-95' : 'animate-[scaleIn_0.15s_ease-out]'
        }`}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-3 border-b border-gray-200/50 dark:border-white/5 shrink-0">
          <div className="flex items-center gap-3 min-w-0">
            <StatusBadge status={status} />
            <span className="text-xs text-gray-400 dark:text-gray-500 truncate">
              {new Date(meeting.created_at).toLocaleDateString()}
            </span>
          </div>
          <button
            onClick={animateClose}
            className="p-1.5 rounded-lg hover:bg-gray-200/80 dark:hover:bg-white/10 text-gray-500 dark:text-gray-400 transition-colors shrink-0"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Two-column body */}
        <div className="flex-1 overflow-hidden flex flex-col md:flex-row min-h-0">
          {/* ─── Left column: metadata ─── */}
          <div className="md:w-1/2 overflow-y-auto p-5 space-y-4 border-b md:border-b-0 md:border-r border-gray-200/50 dark:border-white/5">
            {/* Title */}
            <input
              type="text"
              value={title}
              onChange={e => setTitle(e.target.value)}
              onBlur={handleTitleBlur}
              className="w-full text-lg font-semibold bg-transparent text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none"
              placeholder="Meeting title"
            />

            {/* Date & time */}
            <div>
              <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Date & Time</label>
              <input
                type="datetime-local"
                value={meetingDate}
                onChange={e => handleDateChange(e.target.value)}
                className="w-full px-3 py-2 text-sm bg-gray-50 dark:bg-white/5 border border-gray-200 dark:border-white/10 rounded-lg text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[var(--accent)]/40"
              />
            </div>

            {/* Status */}
            <div>
              <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Status</label>
              <CustomSelect
                value={status}
                onChange={val => handleStatusChange(val as MeetingStatus)}
                options={STATUS_OPTIONS}
                size="md"
                className="w-full"
              />
            </div>

            {/* Duration */}
            <div>
              <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Duration (minutes)</label>
              <input
                type="number"
                value={duration}
                onChange={e => setDuration(parseInt(e.target.value) || 0)}
                onBlur={handleDurationBlur}
                min={0}
                className="w-full px-3 py-2 text-sm bg-gray-50 dark:bg-white/5 border border-gray-200 dark:border-white/10 rounded-lg text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[var(--accent)]/40"
              />
            </div>

            {/* Participants */}
            <div>
              <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Participants</label>
              <div className="px-3 py-2 bg-gray-50 dark:bg-white/5 border border-gray-200 dark:border-white/10 rounded-lg">
                <TagInput tags={participants} onChange={handleParticipantsChange} placeholder="Add participant..." />
              </div>
            </div>

            {/* Tags */}
            <div>
              <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Tags</label>
              <div className="px-3 py-2 bg-gray-50 dark:bg-white/5 border border-gray-200 dark:border-white/10 rounded-lg">
                <TagInput tags={tags} onChange={handleTagsChange} placeholder="Add tag..." />
              </div>
            </div>

            {/* Agenda builder */}
            <div>
              <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">
                Agenda ({agenda.filter(a => a.completed).length}/{agenda.length} completed)
              </label>
              <div className="space-y-1.5">
                {agenda.map((item, idx) => (
                  <div key={idx} className="flex items-center gap-2 group">
                    <button
                      type="button"
                      onClick={() => handleToggleAgendaItem(idx)}
                      className={`w-4 h-4 rounded border shrink-0 flex items-center justify-center transition-colors ${
                        item.completed
                          ? 'bg-black dark:bg-white border-black dark:border-white text-white dark:text-black'
                          : 'border-gray-300 dark:border-gray-600 hover:border-black dark:hover:border-white'
                      }`}
                    >
                      {item.completed && (
                        <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                      )}
                    </button>
                    <span className={`flex-1 text-sm ${
                      item.completed
                        ? 'line-through text-gray-400 dark:text-gray-600'
                        : 'text-gray-700 dark:text-gray-300'
                    }`}>
                      {item.text}
                    </span>
                    <button
                      type="button"
                      onClick={() => handleRemoveAgendaItem(idx)}
                      className="p-0.5 text-gray-400 hover:text-red-500 opacity-0 group-hover:opacity-100 transition-all shrink-0"
                    >
                      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                ))}
                {/* Add new agenda item */}
                <div className="flex items-center gap-2">
                  <div className="w-4 shrink-0" />
                  <input
                    type="text"
                    value={newAgendaText}
                    onChange={e => setNewAgendaText(e.target.value)}
                    onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); handleAddAgendaItem() } }}
                    placeholder="Add agenda item..."
                    className="flex-1 text-sm bg-transparent text-gray-700 dark:text-gray-300 placeholder-gray-400 dark:placeholder-gray-600 focus:outline-none"
                  />
                  {newAgendaText.trim() && (
                    <button
                      type="button"
                      onClick={handleAddAgendaItem}
                      className="text-xs text-black dark:text-white hover:underline font-medium shrink-0"
                    >
                      Add
                    </button>
                  )}
                </div>
              </div>
            </div>

            {/* Delete */}
            <div className="pt-4 border-t border-gray-200/50 dark:border-white/5">
              {!confirmDelete ? (
                <button
                  type="button"
                  onClick={() => setConfirmDelete(true)}
                  className="text-xs text-red-500 hover:text-red-600 font-medium transition-colors"
                >
                  Delete Meeting
                </button>
              ) : (
                <div className="flex items-center gap-3">
                  <span className="text-xs text-red-500">Are you sure?</span>
                  <button
                    type="button"
                    onClick={handleDelete}
                    className="px-3 py-1 text-xs bg-red-500 hover:bg-red-600 text-white rounded-lg font-medium transition-colors"
                  >
                    Yes, delete
                  </button>
                  <button
                    type="button"
                    onClick={() => setConfirmDelete(false)}
                    className="px-3 py-1 text-xs text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 transition-colors"
                  >
                    Cancel
                  </button>
                </div>
              )}
            </div>
          </div>

          {/* ─── Right column: AI content ─── */}
          <div className="md:w-1/2 overflow-y-auto p-5 space-y-5">
            {/* AI error */}
            {aiError && (
              <div className="text-xs text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-900/20 rounded-lg p-3">
                {aiError}
                <button onClick={() => setAiError('')} className="ml-2 underline">Dismiss</button>
              </div>
            )}

            {/* Recording section */}
            <div>
              <h4 className="text-xs font-semibold text-gray-900 dark:text-white uppercase tracking-wide mb-2">Recording</h4>
              <div className="flex items-center gap-3">
                {!recorder.recording ? (
                  <button
                    type="button"
                    onClick={handleStartRecording}
                    disabled={transcribing}
                    className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium bg-red-500 hover:bg-red-600 disabled:opacity-50 text-white rounded-lg transition-colors"
                  >
                    <svg className="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
                      <circle cx="12" cy="12" r="8" />
                    </svg>
                    Record
                  </button>
                ) : (
                  <>
                    <button
                      type="button"
                      onClick={handleStopRecording}
                      className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium bg-gray-700 hover:bg-gray-800 text-white rounded-lg transition-colors"
                    >
                      <svg className="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
                        <rect x="6" y="6" width="12" height="12" rx="2" />
                      </svg>
                      Stop
                    </button>
                    <div className="flex items-center gap-2">
                      <span className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
                      <span className="text-xs font-mono text-gray-600 dark:text-gray-400">{formatTimer(recordingSeconds)}</span>
                    </div>
                  </>
                )}
                {transcribing && (
                  <div className="flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400">
                    <div className="w-3.5 h-3.5 border-2 border-black dark:border-white border-t-transparent rounded-full animate-spin" />
                    Transcribing...
                  </div>
                )}
                {recorder.uploading && (
                  <span className="text-xs text-gray-500 dark:text-gray-400">Uploading audio...</span>
                )}
              </div>
              {/* Show transcript text if available */}
              {transcriptText && (
                <div className="mt-3 p-3 bg-gray-50 dark:bg-white/5 rounded-lg text-xs text-gray-700 dark:text-gray-300 whitespace-pre-wrap max-h-32 overflow-y-auto border border-gray-200/50 dark:border-white/5">
                  {transcriptText}
                </div>
              )}
            </div>

            {/* AI Notes section */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <h4 className="text-xs font-semibold text-gray-900 dark:text-white uppercase tracking-wide">AI Notes</h4>
                <button
                  type="button"
                  onClick={handleGenerateNotes}
                  disabled={generatingNotes}
                  className="flex items-center gap-1.5 px-2.5 py-1 text-[11px] font-medium text-black dark:text-white bg-black/10 dark:bg-white/10 hover:bg-black/20 dark:hover:bg-white/20 disabled:opacity-50 rounded-lg transition-colors"
                >
                  {generatingNotes ? (
                    <>
                      <div className="w-3 h-3 border-2 border-black dark:border-white border-t-transparent rounded-full animate-spin" />
                      Generating...
                    </>
                  ) : (
                    <>
                      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456z" />
                      </svg>
                      Generate Notes
                    </>
                  )}
                </button>
              </div>
              {aiNotes ? (
                <div className="p-3 bg-gray-50 dark:bg-white/5 rounded-lg text-xs text-gray-700 dark:text-gray-300 whitespace-pre-wrap max-h-48 overflow-y-auto border border-gray-200/50 dark:border-white/5">
                  {aiNotes}
                </div>
              ) : (
                <p className="text-xs text-gray-400 dark:text-gray-600 italic">
                  {transcriptText || meeting.transcript_id
                    ? 'Click "Generate Notes" to create AI-powered meeting notes.'
                    : 'Record or link a transcript to generate AI notes.'}
                </p>
              )}
            </div>

            {/* Follow-up Email section */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <h4 className="text-xs font-semibold text-gray-900 dark:text-white uppercase tracking-wide">Follow-up Email</h4>
                <button
                  type="button"
                  onClick={handleGenerateFollowUp}
                  disabled={generatingFollowUp}
                  className="flex items-center gap-1.5 px-2.5 py-1 text-[11px] font-medium text-black dark:text-white bg-black/10 dark:bg-white/10 hover:bg-black/20 dark:hover:bg-white/20 disabled:opacity-50 rounded-lg transition-colors"
                >
                  {generatingFollowUp ? (
                    <>
                      <div className="w-3 h-3 border-2 border-black dark:border-white border-t-transparent rounded-full animate-spin" />
                      Generating...
                    </>
                  ) : (
                    <>
                      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75" />
                      </svg>
                      Generate Follow-up
                    </>
                  )}
                </button>
              </div>
              {followUp ? (
                <div className="p-3 bg-gray-50 dark:bg-white/5 rounded-lg text-xs text-gray-700 dark:text-gray-300 whitespace-pre-wrap max-h-48 overflow-y-auto border border-gray-200/50 dark:border-white/5">
                  {followUp}
                </div>
              ) : (
                <p className="text-xs text-gray-400 dark:text-gray-600 italic">
                  Generate meeting notes first, then create a follow-up email.
                </p>
              )}
            </div>

            {/* Usage info for non-admin */}
            {user && !isAdmin && (
              <div className="text-[10px] text-gray-400 dark:text-gray-600 pt-2">
                AI Notes: {getDailyUsage('meeting_notes', user.id, AI_LIMITS.meeting_notes.daily).remaining}/{AI_LIMITS.meeting_notes.daily} remaining today
                {' | '}
                Transcriptions: {getDailyUsage('transcript', user.id, AI_LIMITS.transcript.daily).remaining}/{AI_LIMITS.transcript.daily} remaining today
              </div>
            )}
          </div>
        </div>
      </div>
    </div>,
    document.body
  )
}
