import { useState } from 'react'
import type { Editor } from '@tiptap/react'
import { generateEmail, generateMessage, getDailyUsage, addDailyUsage, AI_LIMITS, AI_KEY_CONFIGURED } from '../../../lib/gemini'
import { useAuth } from '../../../context/AuthContext'
import CustomSelect from '../../shared/CustomSelect'

interface AIWriterModalProps {
  editor: Editor
  onClose: () => void
}

type WriterTab = 'email' | 'message'
type Tone = 'casual' | 'short' | 'professional' | 'friendly' | 'formal'

const TONES: { value: Tone; label: string }[] = [
  { value: 'professional', label: 'Professional' },
  { value: 'casual', label: 'Casual' },
  { value: 'short', label: 'Short & Concise' },
  { value: 'friendly', label: 'Friendly' },
  { value: 'formal', label: 'Formal' },
]

export default function AIWriterModal({ editor, onClose }: AIWriterModalProps) {
  const { user, profile } = useAuth()
  const isAdmin = profile?.is_admin === true

  const [tab, setTab] = useState<WriterTab>('email')
  const [subject, setSubject] = useState('')
  const [context, setContext] = useState('')
  const [tone, setTone] = useState<Tone>('professional')
  const [result, setResult] = useState('')
  const [generating, setGenerating] = useState(false)
  const [error, setError] = useState('')
  const [copied, setCopied] = useState(false)

  const usage = user ? getDailyUsage('ai_writer', user.id, AI_LIMITS.ai_writer.daily) : { remaining: 0, used: 0 }
  const noUses = !isAdmin && usage.remaining <= 0

  const canGenerate = tab === 'email' ? subject.trim() && context.trim() : context.trim()
  const disabled = generating

  const handleGenerate = async () => {
    if (!AI_KEY_CONFIGURED) { setError('AI key missing — redeploy with VITE_GEMINI_API_KEY env var'); return }
    if (!user) { setError('Not signed in'); return }
    if (noUses) { setError('✨ Premium coming soon — upgrade for unlimited AI'); return }
    if (generating || !canGenerate) return
    setGenerating(true)
    setError('')
    setResult('')

    try {
      let output: string
      if (tab === 'email') {
        output = await generateEmail(subject, context, tone)
      } else {
        output = await generateMessage(context, tone)
      }
      setResult(output)
      if (!isAdmin) addDailyUsage('ai_writer', user.id, 1)
    } catch (err: any) {
      const msg = err?.message || ''
      if (msg.includes('429') || msg.includes('uota')) {
        setError('Rate limit reached. Please try again later.')
      } else {
        setError('Generation failed. Please try again.')
      }
    } finally {
      setGenerating(false)
    }
  }

  const handleInsert = () => {
    if (!result) return
    editor.chain().focus().insertContent(result).run()
    onClose()
  }

  const handleCopy = async () => {
    if (!result) return
    await navigator.clipboard.writeText(result)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const inputClass =
    'w-full px-3 py-2 text-sm bg-gray-100 dark:bg-white/5 border border-gray-200 dark:border-white/10 rounded-lg text-gray-800 dark:text-gray-200 placeholder-gray-400 dark:placeholder-gray-600 focus:outline-none focus:ring-1 focus:ring-[var(--accent)]'

  return (
    <div
      className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/40 backdrop-blur-sm animate-[fadeIn_0.15s_ease-out]"
      onClick={onClose}
    >
      <div
        className="w-[480px] max-h-[85vh] glass-panel-solid rounded-2xl shadow-2xl flex flex-col animate-[scaleIn_0.15s_ease-out]"
        onClick={e => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-5 pb-3">
          <h3 className="text-sm font-semibold text-gray-900 dark:text-white">AI Writer</h3>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg hover:bg-gray-200/80 dark:hover:bg-white/10 text-gray-500 dark:text-gray-400 transition-colors"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Tabs */}
        <div className="flex gap-1 mx-5 p-0.5 bg-gray-100 dark:bg-white/5 rounded-lg">
          {(['email', 'message'] as WriterTab[]).map(t => (
            <button
              key={t}
              onClick={() => { setTab(t); setResult(''); setError('') }}
              className={`flex-1 px-3 py-1.5 text-xs font-medium rounded-md transition-colors capitalize ${
                tab === t
                  ? 'bg-black dark:bg-white text-white dark:text-black'
                  : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'
              }`}
            >
              {t}
            </button>
          ))}
        </div>

        {/* Form */}
        <div className="px-5 py-4 space-y-3 overflow-y-auto">
          {tab === 'email' && (
            <div>
              <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Subject</label>
              <input
                type="text"
                value={subject}
                onChange={e => setSubject(e.target.value)}
                placeholder="Email subject..."
                className={inputClass}
              />
            </div>
          )}

          <div>
            <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">
              {tab === 'email' ? 'Context / Details' : 'What should the message say?'}
            </label>
            <textarea
              value={context}
              onChange={e => setContext(e.target.value)}
              placeholder={tab === 'email' ? 'Key points, recipients, purpose...' : 'Describe the message you want to write...'}
              rows={3}
              className={`${inputClass} resize-none`}
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-gray-600 dark:text-gray-400 mb-1">Tone</label>
            <CustomSelect
              value={tone}
              onChange={val => setTone(val as Tone)}
              options={TONES}
              size="md"
              className="w-full"
            />
          </div>

          <button
            onClick={handleGenerate}
            disabled={disabled}
            className="w-full px-4 py-2 text-sm font-medium bg-black dark:bg-white text-white dark:text-black hover:bg-gray-800 dark:hover:bg-gray-200 rounded-lg disabled:opacity-40 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
          >
            {generating ? (
              <>
                <div className="w-4 h-4 border-2 border-white dark:border-black border-t-transparent rounded-full animate-spin" />
                Generating...
              </>
            ) : (
              <>Generate {tab === 'email' ? 'Email' : 'Message'}</>
            )}
            {!isAdmin && !generating && (
              <span className={`text-[10px] ${noUses ? 'text-red-300' : 'text-gray-300 dark:text-gray-600'}`}>
                ({usage.remaining})
              </span>
            )}
            {isAdmin && !generating && <span className="text-[10px] text-amber-300 dark:text-amber-600">&infin;</span>}
          </button>

          {error && (
            <p className="text-sm text-red-500 text-center">{error}</p>
          )}

          {/* Result */}
          {result && (
            <div className="space-y-2">
              <div className="h-px bg-gray-200 dark:bg-white/10" />
              <label className="block text-xs font-medium text-gray-600 dark:text-gray-400">Result</label>
              <div className="max-h-[200px] overflow-y-auto p-3 bg-gray-50 dark:bg-white/5 border border-gray-200 dark:border-white/10 rounded-lg text-sm text-gray-800 dark:text-gray-200 whitespace-pre-wrap">
                {result}
              </div>
              <div className="flex items-center justify-end gap-2">
                <button
                  onClick={handleCopy}
                  className="px-3 py-1.5 text-sm text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-white/10 rounded-lg transition-colors"
                >
                  {copied ? 'Copied!' : 'Copy'}
                </button>
                <button
                  onClick={handleInsert}
                  className="px-4 py-1.5 text-sm font-medium bg-black dark:bg-white text-white dark:text-black hover:bg-gray-800 dark:hover:bg-gray-200 rounded-lg transition-colors"
                >
                  Insert into Note
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
