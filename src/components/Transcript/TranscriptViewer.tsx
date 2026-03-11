import { useState, useMemo } from 'react'
import { useAuth } from '../../context/AuthContext'
import { useSettings } from '../../hooks/useSettings'
import { generateTranscriptSummary, extractActionItems, getDailyUsage, addDailyUsage, AI_LIMITS } from '../../lib/gemini'
import TagInput from '../shared/TagInput'
import type { Transcript } from '../../types'

interface TranscriptViewerProps {
  transcript: Transcript
  onUpdate: (id: string, updates: Partial<Transcript>) => Promise<any>
  onDelete: (id: string) => Promise<void>
}

type TabKey = 'transcript' | 'summary' | 'actions'

const SPEAKER_COLORS = [
  'text-blue-600 dark:text-blue-400',
  'text-emerald-600 dark:text-emerald-400',
  'text-purple-600 dark:text-purple-400',
  'text-orange-600 dark:text-orange-400',
  'text-pink-600 dark:text-pink-400',
  'text-teal-600 dark:text-teal-400',
]

export default function TranscriptViewer({ transcript, onUpdate, onDelete }: TranscriptViewerProps) {
  const { user, profile } = useAuth()
  const { settings } = useSettings()
  const [activeTab, setActiveTab] = useState<TabKey>('transcript')
  const [searchText, setSearchText] = useState('')
  const [generatingSummary, setGeneratingSummary] = useState(false)
  const [extractingActions, setExtractingActions] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [confirmDelete, setConfirmDelete] = useState(false)

  const isAdmin = profile?.is_admin === true

  // Map speakers to colors
  const speakerColorMap = useMemo(() => {
    const map: Record<string, string> = {}
    const speakers = new Set<string>()
    for (const seg of transcript.speaker_segments || []) {
      speakers.add(seg.speaker)
    }
    let i = 0
    for (const speaker of speakers) {
      map[speaker] = SPEAKER_COLORS[i % SPEAKER_COLORS.length]
      i++
    }
    return map
  }, [transcript.speaker_segments])

  // Highlight matching text in a string
  const highlightText = (text: string) => {
    if (!searchText.trim()) return text
    const regex = new RegExp(`(${searchText.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi')
    const parts = text.split(regex)
    return parts.map((part, i) =>
      i % 2 === 1 ? (
        <mark key={i} className="bg-yellow-200 dark:bg-yellow-800/60 text-inherit rounded px-0.5">
          {part}
        </mark>
      ) : (
        part
      )
    )
  }

  const handleGenerateSummary = async () => {
    if (!user) return
    if (!isAdmin) {
      const { remaining } = getDailyUsage('transcript', user.id, AI_LIMITS.transcript.daily)
      if (remaining <= 0) {
        setError('✨ Premium coming soon — upgrade for unlimited AI')
        setTimeout(() => setError(null), 4000)
        return
      }
    }
    setGeneratingSummary(true)
    setError(null)
    try {
      const text = transcript.transcript_text || transcript.speaker_segments?.map(s => `${s.speaker}: ${s.text}`).join('\n') || ''
      const summary = await generateTranscriptSummary(text, settings?.ai_tone || 'professional', settings?.summary_length || 'medium')
      await onUpdate(transcript.id, { summary })
      if (!isAdmin) addDailyUsage('transcript', user.id, 1)
    } catch (err: any) {
      const msg = err?.message || ''
      if (msg.includes('429') || msg.includes('uota')) {
        setError('Rate limit reached. Please try again later.')
      } else {
        setError('Failed to generate summary. Please try again.')
      }
      setTimeout(() => setError(null), 4000)
    } finally {
      setGeneratingSummary(false)
    }
  }

  const handleExtractActions = async () => {
    if (!user) return
    if (!isAdmin) {
      const { remaining } = getDailyUsage('action_items', user.id, AI_LIMITS.action_items.daily)
      if (remaining <= 0) {
        setError('✨ Premium coming soon — upgrade for unlimited AI')
        setTimeout(() => setError(null), 4000)
        return
      }
    }
    setExtractingActions(true)
    setError(null)
    try {
      const text = transcript.transcript_text || transcript.speaker_segments?.map(s => `${s.speaker}: ${s.text}`).join('\n') || ''
      const actions = await extractActionItems(text)
      await onUpdate(transcript.id, { action_items: actions })
      if (!isAdmin) addDailyUsage('action_items', user.id, 1)
    } catch (err: any) {
      const msg = err?.message || ''
      if (msg.includes('429') || msg.includes('uota')) {
        setError('Rate limit reached. Please try again later.')
      } else {
        setError('Failed to extract action items. Please try again.')
      }
      setTimeout(() => setError(null), 4000)
    } finally {
      setExtractingActions(false)
    }
  }

  const handleTagsChange = (tags: string[]) => {
    onUpdate(transcript.id, { tags })
  }

  const handleDelete = async () => {
    if (!confirmDelete) {
      setConfirmDelete(true)
      setTimeout(() => setConfirmDelete(false), 3000)
      return
    }
    await onDelete(transcript.id)
  }

  const tabs: { key: TabKey; label: string }[] = [
    { key: 'transcript', label: 'Transcript' },
    { key: 'summary', label: 'Summary' },
    { key: 'actions', label: 'Action Items' },
  ]

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="px-5 pt-4 pb-2 shrink-0">
        <h2 className="text-lg font-semibold text-gray-900 dark:text-white truncate">
          {transcript.title || 'Untitled Transcript'}
        </h2>
        <p className="text-xs text-gray-400 dark:text-gray-500 mt-0.5">
          {new Date(transcript.created_at).toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })}
          {transcript.duration_seconds > 0 && (
            <> &middot; {Math.floor(transcript.duration_seconds / 60)}m {transcript.duration_seconds % 60}s</>
          )}
        </p>
      </div>

      {/* Tabs */}
      <div className="flex items-center gap-1 px-5 shrink-0 border-b border-gray-200/50 dark:border-white/5">
        {tabs.map(tab => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`px-3 py-2 text-xs font-medium border-b-2 transition-colors ${
              activeTab === tab.key
                ? 'border-[var(--accent)] text-[var(--accent)]'
                : 'border-transparent text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Error */}
      {error && (
        <div className="mx-5 mt-2 px-3 py-2 text-xs text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-900/20 rounded-lg">
          {error}
        </div>
      )}

      {/* Tab content */}
      <div className="flex-1 overflow-y-auto px-5 py-3">
        {activeTab === 'transcript' && (
          <div className="space-y-3">
            {/* Search bar */}
            <div className="relative">
              <svg className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
              <input
                type="text"
                value={searchText}
                onChange={e => setSearchText(e.target.value)}
                placeholder="Search in transcript..."
                className="w-full pl-8 pr-3 py-1.5 text-xs bg-gray-100 dark:bg-white/5 border border-gray-200 dark:border-white/10 rounded-lg text-gray-700 dark:text-gray-300 placeholder-gray-400 dark:placeholder-gray-600 focus:outline-none focus:ring-1 focus:ring-[var(--accent)]"
              />
            </div>

            {/* Speaker segments or plain text */}
            {transcript.speaker_segments && transcript.speaker_segments.length > 0 ? (
              <div className="space-y-2">
                {transcript.speaker_segments.map((seg, i) => (
                  <div key={i} className="flex gap-2">
                    <span className={`text-xs font-semibold shrink-0 pt-0.5 min-w-[80px] ${speakerColorMap[seg.speaker] || 'text-gray-600 dark:text-gray-400'}`}>
                      {seg.speaker}
                    </span>
                    <p className="text-sm text-gray-700 dark:text-gray-300 leading-relaxed">
                      {highlightText(seg.text)}
                    </p>
                  </div>
                ))}
              </div>
            ) : transcript.transcript_text ? (
              <p className="text-sm text-gray-700 dark:text-gray-300 leading-relaxed whitespace-pre-wrap">
                {highlightText(transcript.transcript_text)}
              </p>
            ) : (
              <p className="text-sm text-gray-400 dark:text-gray-500 italic">No transcript text available.</p>
            )}
          </div>
        )}

        {activeTab === 'summary' && (
          <div className="space-y-3">
            {transcript.summary ? (
              <>
                <div
                  className="text-sm text-gray-700 dark:text-gray-300 leading-relaxed whitespace-pre-wrap"
                  dangerouslySetInnerHTML={{
                    __html: transcript.summary
                      .replace(/^- /gm, '&bull; ')
                      .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
                      .replace(/\*(.*?)\*/g, '<em>$1</em>')
                  }}
                />
                <button
                  onClick={handleGenerateSummary}
                  disabled={generatingSummary}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-600 dark:text-gray-400 bg-gray-100 dark:bg-white/5 rounded-lg hover:bg-gray-200 dark:hover:bg-white/10 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {generatingSummary ? (
                    <>
                      <div className="w-3 h-3 border-2 border-current border-t-transparent rounded-full animate-spin" />
                      Regenerating...
                    </>
                  ) : (
                    <>
                      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                      </svg>
                      Regenerate
                    </>
                  )}
                </button>
              </>
            ) : (
              <div className="flex flex-col items-center justify-center py-12 gap-3">
                <div className="w-12 h-12 rounded-xl bg-[var(--accent)]/10 flex items-center justify-center">
                  <svg className="w-6 h-6 text-[var(--accent)]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456z" />
                  </svg>
                </div>
                <p className="text-sm text-gray-500 dark:text-gray-400">No summary generated yet</p>
                <button
                  onClick={handleGenerateSummary}
                  disabled={generatingSummary}
                  className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium bg-black dark:bg-white text-white dark:text-black hover:bg-gray-800 dark:hover:bg-gray-200 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {generatingSummary ? (
                    <>
                      <div className="w-3.5 h-3.5 border-2 border-black dark:border-white border-t-transparent rounded-full animate-spin" />
                      Generating...
                    </>
                  ) : (
                    <>
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
                      </svg>
                      Generate Summary
                    </>
                  )}
                </button>
              </div>
            )}
          </div>
        )}

        {activeTab === 'actions' && (
          <div className="space-y-3">
            {transcript.action_items ? (
              <>
                <div
                  className="text-sm text-gray-700 dark:text-gray-300 leading-relaxed whitespace-pre-wrap"
                  dangerouslySetInnerHTML={{
                    __html: transcript.action_items
                      .replace(/- \[ \]/g, '<span class="inline-block w-3.5 h-3.5 border border-gray-400 rounded mr-1.5 align-text-bottom"></span>')
                      .replace(/- \[x\]/gi, '<span class="inline-block w-3.5 h-3.5 bg-[var(--accent)] border border-[var(--accent)] rounded mr-1.5 align-text-bottom relative"><svg class="absolute inset-0 w-3.5 h-3.5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" /></svg></span>')
                      .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
                  }}
                />
                <button
                  onClick={handleExtractActions}
                  disabled={extractingActions}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-gray-600 dark:text-gray-400 bg-gray-100 dark:bg-white/5 rounded-lg hover:bg-gray-200 dark:hover:bg-white/10 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {extractingActions ? (
                    <>
                      <div className="w-3 h-3 border-2 border-current border-t-transparent rounded-full animate-spin" />
                      Re-extracting...
                    </>
                  ) : (
                    <>
                      <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                      </svg>
                      Re-extract
                    </>
                  )}
                </button>
              </>
            ) : (
              <div className="flex flex-col items-center justify-center py-12 gap-3">
                <div className="w-12 h-12 rounded-xl bg-[var(--accent)]/10 flex items-center justify-center">
                  <svg className="w-6 h-6 text-[var(--accent)]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <p className="text-sm text-gray-500 dark:text-gray-400">No action items extracted yet</p>
                <button
                  onClick={handleExtractActions}
                  disabled={extractingActions}
                  className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium bg-black dark:bg-white text-white dark:text-black hover:bg-gray-800 dark:hover:bg-gray-200 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  {extractingActions ? (
                    <>
                      <div className="w-3.5 h-3.5 border-2 border-black dark:border-white border-t-transparent rounded-full animate-spin" />
                      Extracting...
                    </>
                  ) : (
                    <>
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      Extract Action Items
                    </>
                  )}
                </button>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Bottom bar: tags + delete */}
      <div className="shrink-0 px-5 py-3 border-t border-gray-200/50 dark:border-white/5 flex items-center gap-3">
        <div className="flex-1 min-w-0">
          <TagInput
            tags={transcript.tags || []}
            onChange={handleTagsChange}
            placeholder="Add tag..."
          />
        </div>
        <button
          onClick={handleDelete}
          className={`shrink-0 px-3 py-1.5 text-xs font-medium rounded-lg transition-colors ${
            confirmDelete
              ? 'bg-red-500 text-white hover:bg-red-600'
              : 'text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20'
          }`}
        >
          {confirmDelete ? 'Confirm Delete' : 'Delete'}
        </button>
      </div>
    </div>
  )
}
