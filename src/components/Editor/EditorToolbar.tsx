import { useState, useRef, useEffect, useCallback, memo } from 'react'
import type { Editor } from '@tiptap/react'
import { FONT_SIZES } from './extensions/FontSize'
import LinkModal from './modals/LinkModal'
import VoiceRecorderModal from './modals/VoiceRecorderModal'
import TableInsertModal from './modals/TableInsertModal'
import { useImageUpload } from './hooks/useImageUpload'
import { exportAsDocx } from './export/exportDocx'
import { exportAsExcel } from './export/exportExcel'
import { exportAsCsv } from './export/exportCsv'
import { exportAsTxt } from './export/exportTxt'
import { summarizeText, fixGrammar, fixCode, getCodeFixUsage, addCodeFixUsage, getDailyUsage, addDailyUsage, AI_LIMITS, AI_KEY_CONFIGURED } from '../../lib/gemini'
import { useAuth } from '../../context/AuthContext'
import AIWriterModal from './modals/AIWriterModal'
import type { NoteType } from '../../types'

const TEXT_COLORS = [
  '#000000', '#434343', '#666666', '#999999',
  '#ef4444', '#f97316', '#eab308', '#22c55e',
  '#3b82f6', '#8b5cf6', '#ec4899', '#14b8a6',
]

const HIGHLIGHT_COLORS = [
  '#fef08a', '#bbf7d0', '#bfdbfe', '#e9d5ff',
  '#fecaca', '#fed7aa', '#fce7f3', '#ccfbf1',
]

const CODE_TYPES: NoteType[] = ['java', 'javascript', 'python', 'sql']

const EMOJIS = [
  '😀', '😊', '😂', '😍', '🥰', '😎', '🤔', '😢', '😡', '🥳',
  '👍', '👎', '👏', '🙌', '🤝', '✌️', '💪', '🙏', '🫡', '🤙',
  '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '💔', '💕', '💯',
  '⭐', '🔥', '✅', '❌', '⚡', '💡', '📌', '🎯', '🏆', '💰',
  '📅', '📝', '🔔', '💬', '📎', '🎉', '🌟', '💎', '🚀', '✨',
]

interface EditorToolbarProps {
  editor: Editor
  title: string
  noteType: NoteType
}

function EditorToolbarInner({ editor, title, noteType }: EditorToolbarProps) {
  const { user, profile } = useAuth()
  const isAdmin = profile?.is_admin === true
  const [showLinkModal, setShowLinkModal] = useState(false)
  const [showVoiceModal, setShowVoiceModal] = useState(false)
  const [showTableModal, setShowTableModal] = useState(false)
  const [showSizeMenu, setShowSizeMenu] = useState(false)
  const [showColorMenu, setShowColorMenu] = useState(false)
  const [showHighlightMenu, setShowHighlightMenu] = useState(false)
  const [showExportMenu, setShowExportMenu] = useState(false)
  const [summarizing, setSummarizing] = useState(false)
  const [fixingGrammar, setFixingGrammar] = useState(false)
  const [fixingCode, setFixingCode] = useState(false)
  const [aiError, setAiError] = useState<string | null>(null)
  const [showAIWriterModal, setShowAIWriterModal] = useState(false)
  const [showEmojiMenu, setShowEmojiMenu] = useState(false)

  // Cheap O(1) flag for "has any text" — used for disabling buttons.
  // Uses ProseMirror doc content size (empty paragraph = 2).
  const [hasText, setHasText] = useState(() => editor.state.doc.content.size > 2)
  const textDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    const handler = () => {
      // O(1) check — update immediately
      setHasText(editor.state.doc.content.size > 2)
      // No getText() here — let onClick handlers fetch fresh text on demand
    }
    // 'update' fires on normal user edits
    editor.on('update', handler)
    // 'transaction' catches setContent with emitUpdate:false (e.g. async initial content load)
    editor.on('transaction', handler)
    // Safety net: re-check after NoteEditor's async content load (requestAnimationFrame + emitUpdate:false)
    const timer = setTimeout(handler, 200)
    return () => {
      editor.off('update', handler)
      editor.off('transaction', handler)
      clearTimeout(timer)
      if (textDebounceRef.current) clearTimeout(textDebounceRef.current)
    }
  }, [editor])

  const toolbarRef = useRef<HTMLDivElement>(null)
  const tableButtonRef = useRef<HTMLButtonElement>(null)
  const imageInputRef = useRef<HTMLInputElement>(null)
  const { uploadImage } = useImageUpload()

  const handleImagePick = useCallback(async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    // Reset so the same file can be picked again
    e.target.value = ''
    const url = await uploadImage(file)
    if (url) {
      editor.chain().focus().setImage({ src: url }).run()
    }
  }, [editor, uploadImage])

  // Close all dropdowns when clicking outside the toolbar
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (toolbarRef.current && !toolbarRef.current.contains(e.target as Node)) {
        setShowSizeMenu(false)
        setShowColorMenu(false)
        setShowHighlightMenu(false)
        setShowExportMenu(false)
        setShowEmojiMenu(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  const closeAllMenus = useCallback(() => {
    setShowSizeMenu(false)
    setShowColorMenu(false)
    setShowHighlightMenu(false)
    setShowExportMenu(false)
    setShowEmojiMenu(false)
  }, [])

  const btn = useCallback(
    (active: boolean) =>
      `p-1.5 rounded-lg transition-colors shrink-0 ${
        active
          ? 'bg-[var(--accent)]/20 text-[var(--accent)]'
          : 'text-gray-500 dark:text-gray-400 hover:bg-gray-100/80 dark:hover:bg-white/10'
      }`,
    []
  )

  const handleExportDocx = async () => {
    closeAllMenus()
    try {
      await exportAsDocx(title, editor.getHTML())
    } catch (err) {
      console.error('Export to Word failed:', err)
    }
  }

  const handleExportExcel = () => {
    closeAllMenus()
    try {
      exportAsExcel(title, editor.getHTML())
    } catch (err) {
      console.error('Export to Excel failed:', err)
    }
  }

  const handleExportCsv = () => {
    closeAllMenus()
    try {
      exportAsCsv(title, editor.getHTML())
    } catch (err) {
      console.error('Export to CSV failed:', err)
    }
  }

  const handleExportTxt = () => {
    closeAllMenus()
    try {
      exportAsTxt(title, editor.getHTML())
    } catch (err) {
      console.error('Export to TXT failed:', err)
    }
  }

  const divider = <div className="w-px h-5 bg-gray-200 dark:bg-white/10 shrink-0 mx-0.5" />

  return (
    <>
      {/* onMouseDown preventDefault keeps editor focused when clicking toolbar buttons */}
      <div
        ref={toolbarRef}
        onMouseDown={(e) => {
          // Don't preventDefault on inputs/selects inside modals
          const target = e.target as HTMLElement
          if (target.tagName === 'INPUT' || target.tagName === 'SELECT' || target.tagName === 'TEXTAREA') return
          e.preventDefault()
        }}
        className="flex items-center gap-0.5 px-3 py-1.5 border-b border-gray-200/50 dark:border-white/5 shrink-0 flex-wrap"
      >
        {/* ── Undo / Redo ── */}
        <button
          onClick={() => editor.chain().focus().undo().run()}
          disabled={!editor.can().undo()}
          className={`${btn(false)} ${!editor.can().undo() ? 'opacity-30 cursor-not-allowed' : ''}`}
          title="Undo"
        >
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M12.5 8c-2.65 0-5.05.99-6.9 2.6L2 7v9h9l-3.62-3.62c1.39-1.16 3.16-1.88 5.12-1.88 3.54 0 6.55 2.31 7.6 5.5l2.37-.78C21.08 11.03 17.15 8 12.5 8z"/></svg>
        </button>
        <button
          onClick={() => editor.chain().focus().redo().run()}
          disabled={!editor.can().redo()}
          className={`${btn(false)} ${!editor.can().redo() ? 'opacity-30 cursor-not-allowed' : ''}`}
          title="Redo"
        >
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M18.4 10.6C16.55 8.99 14.15 8 11.5 8c-4.65 0-8.58 3.03-9.96 7.22L3.9 16c1.05-3.19 4.05-5.5 7.6-5.5 1.95 0 3.73.72 5.12 1.88L13 16h9V7l-3.6 3.6z"/></svg>
        </button>

        {divider}

        {/* ── Format group ── */}
        <button onClick={() => editor.chain().focus().toggleBold().run()} className={btn(editor.isActive('bold'))} title="Bold">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M15.6 10.79c.97-.67 1.65-1.77 1.65-2.79 0-2.26-1.75-4-4-4H7v14h7.04c2.09 0 3.71-1.7 3.71-3.79 0-1.52-.86-2.82-2.15-3.42zM10 6.5h3c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5h-3v-3zm3.5 9H10v-3h3.5c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5z" /></svg>
        </button>
        <button onClick={() => editor.chain().focus().toggleItalic().run()} className={btn(editor.isActive('italic'))} title="Italic">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M10 4v3h2.21l-3.42 8H6v3h8v-3h-2.21l3.42-8H18V4z" /></svg>
        </button>
        <button onClick={() => editor.chain().focus().toggleUnderline().run()} className={btn(editor.isActive('underline'))} title="Underline">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M12 17c3.31 0 6-2.69 6-6V3h-2.5v8c0 1.93-1.57 3.5-3.5 3.5S8.5 12.93 8.5 11V3H6v8c0 3.31 2.69 6 6 6zm-7 2v2h14v-2H5z" /></svg>
        </button>
        <button onClick={() => editor.chain().focus().toggleStrike().run()} className={btn(editor.isActive('strike'))} title="Strikethrough">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M10 19h4v-3h-4v3zM5 4v3h5v3h4V7h5V4H5zM3 14h18v-2H3v2z" /></svg>
        </button>

        {divider}

        {/* ── Font size ── */}
        <div className="relative">
          <button
            onClick={() => { closeAllMenus(); setShowSizeMenu((v) => !v) }}
            className={`${btn(editor.isActive('heading'))} flex items-center gap-0.5 text-xs px-2`}
            title="Font Size"
          >
            <span className="font-medium">Aa</span>
            <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" /></svg>
          </button>
          {showSizeMenu && (
            <div className="absolute top-full left-0 mt-1 z-50 glass-panel-solid rounded-lg shadow-xl py-1 min-w-[140px]">
              {[
                { label: 'Heading 1', active: editor.isActive('heading', { level: 1 }), action: () => editor.chain().focus().toggleHeading({ level: 1 }).run() },
                { label: 'Heading 2', active: editor.isActive('heading', { level: 2 }), action: () => editor.chain().focus().toggleHeading({ level: 2 }).run() },
                { label: 'Heading 3', active: editor.isActive('heading', { level: 3 }), action: () => editor.chain().focus().toggleHeading({ level: 3 }).run() },
                { label: 'Paragraph', active: editor.isActive('paragraph'), action: () => editor.chain().focus().setParagraph().run() },
              ].map((item) => (
                <button
                  key={item.label}
                  onClick={() => { item.action(); setShowSizeMenu(false) }}
                  className={`w-full text-left px-3 py-1.5 text-sm hover:bg-gray-100 dark:hover:bg-white/10 ${item.active ? 'text-[var(--accent)] font-medium' : 'text-gray-700 dark:text-gray-300'}`}
                >
                  {item.label}
                </button>
              ))}
              <div className="h-px bg-gray-200 dark:bg-white/10 my-1" />
              {FONT_SIZES.map((s) => (
                <button
                  key={s.label}
                  onClick={() => {
                    if (s.value) {
                      editor.chain().focus().setFontSize(s.value).run()
                    } else {
                      editor.chain().focus().unsetFontSize().run()
                    }
                    setShowSizeMenu(false)
                  }}
                  className="w-full text-left px-3 py-1.5 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-white/10"
                >
                  {s.label}
                </button>
              ))}
            </div>
          )}
        </div>

        {divider}

        {/* ── Text color ── */}
        <div className="relative">
          <button
            onClick={() => { closeAllMenus(); setShowColorMenu((v) => !v) }}
            className={btn(!!editor.getAttributes('textStyle').color)}
            title="Text Color"
          >
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
              <path d="M11 2L5.5 16h2.25l1.12-3h6.25l1.12 3h2.25L13 2h-2zm-1.38 9L12 4.67 14.38 11H9.62z" />
              <rect x="3" y="18" width="18" height="3" rx="1" fill={editor.getAttributes('textStyle').color || 'currentColor'} />
            </svg>
          </button>
          {showColorMenu && (
            <div className="absolute top-full left-0 mt-1 z-50 glass-panel-solid rounded-lg shadow-xl p-2">
              <div className="grid grid-cols-4 gap-1.5">
                {TEXT_COLORS.map((c) => (
                  <button
                    key={c}
                    onClick={() => { editor.chain().focus().setColor(c).run(); setShowColorMenu(false) }}
                    className="w-6 h-6 rounded-md border border-gray-200 dark:border-white/20 hover:scale-110 transition-transform"
                    style={{ backgroundColor: c }}
                  />
                ))}
              </div>
              <button
                onClick={() => { editor.chain().focus().unsetColor().run(); setShowColorMenu(false) }}
                className="w-full mt-2 text-xs text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 py-1"
              >
                Reset color
              </button>
            </div>
          )}
        </div>

        {/* ── Highlight color ── */}
        <div className="relative">
          <button
            onClick={() => { closeAllMenus(); setShowHighlightMenu((v) => !v) }}
            className={btn(editor.isActive('highlight'))}
            title="Highlight"
          >
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
              <path d="M18.5 1.15l-4.24 4.24 4.24 4.24 1.41-1.41-2.83-2.83 1.42-1.41-1.42-1.42 1.42-1.41zM5.51 10.01L2.09 13.43l4.24 4.24 3.42-3.42zM15.27 4.38L4.38 15.27 8.62 19.51 19.51 8.62z" />
              <rect x="3" y="20" width="18" height="3" rx="1" fill={editor.getAttributes('highlight').color || '#fef08a'} />
            </svg>
          </button>
          {showHighlightMenu && (
            <div className="absolute top-full left-0 mt-1 z-50 glass-panel-solid rounded-lg shadow-xl p-2">
              <div className="grid grid-cols-4 gap-1.5">
                {HIGHLIGHT_COLORS.map((c) => (
                  <button
                    key={c}
                    onClick={() => { editor.chain().focus().toggleHighlight({ color: c }).run(); setShowHighlightMenu(false) }}
                    className="w-6 h-6 rounded-md border border-gray-200 dark:border-white/20 hover:scale-110 transition-transform"
                    style={{ backgroundColor: c }}
                  />
                ))}
              </div>
              <button
                onClick={() => { editor.chain().focus().unsetHighlight().run(); setShowHighlightMenu(false) }}
                className="w-full mt-2 text-xs text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 py-1"
              >
                Remove highlight
              </button>
            </div>
          )}
        </div>

        {divider}

        {/* ── Alignment ── */}
        <button onClick={() => editor.chain().focus().setTextAlign('left').run()} className={btn(editor.isActive({ textAlign: 'left' }))} title="Align Left">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M15 15H3v2h12v-2zm0-8H3v2h12V7zM3 13h18v-2H3v2zm0 8h18v-2H3v2zM3 3v2h18V3H3z" /></svg>
        </button>
        <button onClick={() => editor.chain().focus().setTextAlign('center').run()} className={btn(editor.isActive({ textAlign: 'center' }))} title="Align Center">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M7 15v2h10v-2H7zm-4 6h18v-2H3v2zm0-8h18v-2H3v2zm4-6v2h10V7H7zM3 3v2h18V3H3z" /></svg>
        </button>
        <button onClick={() => editor.chain().focus().setTextAlign('right').run()} className={btn(editor.isActive({ textAlign: 'right' }))} title="Align Right">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M3 21h18v-2H3v2zm6-4h12v-2H9v2zm-6-4h18v-2H3v2zm6-4h12V7H9v2zM3 3v2h18V3H3z" /></svg>
        </button>
        <button onClick={() => editor.chain().focus().setTextAlign('justify').run()} className={btn(editor.isActive({ textAlign: 'justify' }))} title="Justify">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M3 21h18v-2H3v2zm0-4h18v-2H3v2zm0-4h18v-2H3v2zm0-4h18V7H3v2zM3 3v2h18V3H3z" /></svg>
        </button>

        {divider}

        {/* ── Lists ── */}
        <button onClick={() => editor.chain().focus().toggleBulletList().run()} className={btn(editor.isActive('bulletList'))} title="Bullet List">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M4 10.5c-.83 0-1.5.67-1.5 1.5s.67 1.5 1.5 1.5 1.5-.67 1.5-1.5-.67-1.5-1.5-1.5zm0-6c-.83 0-1.5.67-1.5 1.5S3.17 7.5 4 7.5 5.5 6.83 5.5 6 4.83 4.5 4 4.5zm0 12c-.83 0-1.5.68-1.5 1.5s.68 1.5 1.5 1.5 1.5-.68 1.5-1.5-.67-1.5-1.5-1.5zM7 19h14v-2H7v2zm0-6h14v-2H7v2zm0-8v2h14V5H7z" /></svg>
        </button>
        <button onClick={() => editor.chain().focus().toggleOrderedList().run()} className={btn(editor.isActive('orderedList'))} title="Numbered List">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M2 17h2v.5H3v1h1v.5H2v1h3v-4H2v1zm1-9h1V4H2v1h1v3zm-1 3h1.8L2 13.1v.9h3v-1H3.2L5 10.9V10H2v1zm5-6v2h14V5H7zm0 14h14v-2H7v2zm0-6h14v-2H7v2z" /></svg>
        </button>
        <button onClick={() => editor.chain().focus().toggleTaskList().run()} className={btn(editor.isActive('taskList'))} title="Task List (Checkboxes)">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V5h14v14zM17.99 9l-1.41-1.42-6.59 6.59-2.58-2.57-1.42 1.41 4 3.99z" /></svg>
        </button>
        {editor.isActive('taskList') && (
          <button
            onClick={() => {
              const { doc, tr } = editor.state
              let allChecked = true
              doc.descendants((node) => {
                if (node.type.name === 'taskItem' && !node.attrs.checked) {
                  allChecked = false
                }
              })
              const target = !allChecked
              doc.descendants((node, pos) => {
                if (node.type.name === 'taskItem' && node.attrs.checked !== target) {
                  tr.setNodeMarkup(pos, undefined, { ...node.attrs, checked: target })
                }
              })
              editor.view.dispatch(tr)
            }}
            className={`${btn(false)} text-xs px-2 font-medium`}
            title="Check All / Uncheck All"
          >
            {(() => {
              let allChecked = true
              editor.state.doc.descendants((node) => {
                if (node.type.name === 'taskItem' && !node.attrs.checked) allChecked = false
              })
              return allChecked ? '☐ Uncheck All' : '☑ Check All'
            })()}
          </button>
        )}

        {divider}

        {/* ── Block elements ── */}
        <button onClick={() => editor.chain().focus().toggleBlockquote().run()} className={btn(editor.isActive('blockquote'))} title="Blockquote">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M6 17h3l2-4V7H5v6h3zm8 0h3l2-4V7h-6v6h3z" /></svg>
        </button>
        <button onClick={() => editor.chain().focus().setHorizontalRule().run()} className={btn(false)} title="Horizontal Rule">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><rect x="3" y="11" width="18" height="2" rx="1" /></svg>
        </button>
        <button onClick={() => editor.chain().focus().toggleCodeBlock().run()} className={btn(editor.isActive('codeBlock'))} title="Code Block">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z" /></svg>
        </button>

        {divider}

        {/* ── Insert ── */}
        <button onClick={() => { closeAllMenus(); setShowLinkModal(true) }} className={btn(editor.isActive('link'))} title="Insert Link">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M3.9 12c0-1.71 1.39-3.1 3.1-3.1h4V7H7c-2.76 0-5 2.24-5 5s2.24 5 5 5h4v-1.9H7c-1.71 0-3.1-1.39-3.1-3.1zM8 13h8v-2H8v2zm9-6h-4v1.9h4c1.71 0 3.1 1.39 3.1 3.1s-1.39 3.1-3.1 3.1h-4V17h4c2.76 0 5-2.24 5-5s-2.24-5-5-5z" /></svg>
        </button>
        <button onClick={() => { closeAllMenus(); imageInputRef.current?.click() }} className={btn(false)} title="Insert Image">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z" /></svg>
        </button>
        <input ref={imageInputRef} type="file" accept="image/*" className="hidden" onChange={handleImagePick} />
        <button ref={tableButtonRef} onClick={() => { closeAllMenus(); setShowTableModal(true) }} className={btn(false)} title="Insert Table">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M20 2H4c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zM8 20H4v-4h4v4zm0-6H4v-4h4v4zm0-6H4V4h4v4zm6 12h-4v-4h4v4zm0-6h-4v-4h4v4zm0-6h-4V4h4v4zm6 12h-4v-4h4v4zm0-6h-4v-4h4v4zm0-6h-4V4h4v4z" /></svg>
        </button>
        <button onClick={() => { closeAllMenus(); setShowVoiceModal(true) }} className={btn(false)} title="Voice Recording">
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm-1-9c0-.55.45-1 1-1s1 .45 1 1v6c0 .55-.45 1-1 1s-1-.45-1-1V5zm6 6c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z" /></svg>
        </button>

        {/* ── Emoji picker ── */}
        <div className="relative">
          <button
            onClick={() => { closeAllMenus(); setShowEmojiMenu(v => !v) }}
            className={btn(showEmojiMenu)}
            title="Insert Emoji"
          >
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm3.5-9c.83 0 1.5-.67 1.5-1.5S16.33 8 15.5 8 14 8.67 14 9.5s.67 1.5 1.5 1.5zm-7 0c.83 0 1.5-.67 1.5-1.5S9.33 8 8.5 8 7 8.67 7 9.5 7.67 11 8.5 11zm3.5 6.5c2.33 0 4.31-1.46 5.11-3.5H6.89c.8 2.04 2.78 3.5 5.11 3.5z"/></svg>
          </button>
          {showEmojiMenu && (
            <div className="absolute top-full left-0 mt-1 z-50 glass-panel-solid rounded-lg shadow-xl p-2 w-[280px]">
              <div className="grid grid-cols-10 gap-0.5">
                {EMOJIS.map((emoji) => (
                  <button
                    key={emoji}
                    onClick={() => { editor.chain().focus().insertContent(emoji).run(); setShowEmojiMenu(false) }}
                    className="w-6 h-6 flex items-center justify-center text-base hover:bg-gray-100 dark:hover:bg-white/10 rounded transition-colors"
                  >
                    {emoji}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* ── Table controls (only when inside a table) ── */}
        {editor.isActive('table') && (
          <>
            {divider}
            <button onClick={() => editor.chain().focus().addColumnAfter().run()} className={btn(false)} title="Add Column After">
              <span className="text-xs font-medium">+Col</span>
            </button>
            <button onClick={() => editor.chain().focus().addRowAfter().run()} className={btn(false)} title="Add Row After">
              <span className="text-xs font-medium">+Row</span>
            </button>
            <button onClick={() => editor.chain().focus().deleteColumn().run()} className={`${btn(false)} !text-red-500 dark:!text-red-400`} title="Delete Column">
              <span className="text-xs font-medium">-Col</span>
            </button>
            <button onClick={() => editor.chain().focus().deleteRow().run()} className={`${btn(false)} !text-red-500 dark:!text-red-400`} title="Delete Row">
              <span className="text-xs font-medium">-Row</span>
            </button>
            <button onClick={() => editor.chain().focus().deleteTable().run()} className={`${btn(false)} !text-red-500 dark:!text-red-400`} title="Delete Table">
              <span className="text-xs font-medium">-Tbl</span>
            </button>
          </>
        )}

        {divider}

        {/* ── Export ── */}
        <div className="relative">
          <button
            onClick={() => { closeAllMenus(); setShowExportMenu((v) => !v) }}
            className={`${btn(false)} flex items-center gap-0.5 text-xs px-2`}
            title="Export"
          >
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor"><path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z" /></svg>
            <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}><path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" /></svg>
          </button>
          {showExportMenu && (
            <div className="absolute top-full right-0 mt-1 z-50 glass-panel-solid rounded-lg shadow-xl py-1 min-w-[140px]">
              <button onClick={handleExportDocx} className="w-full text-left px-3 py-1.5 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-white/10">
                Word (.docx)
              </button>
              <button onClick={handleExportExcel} className="w-full text-left px-3 py-1.5 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-white/10">
                Excel (.xlsx)
              </button>
              <button onClick={handleExportCsv} className="w-full text-left px-3 py-1.5 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-white/10">
                CSV (.csv)
              </button>
              <button onClick={handleExportTxt} className="w-full text-left px-3 py-1.5 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-white/10">
                Text (.txt)
              </button>
            </div>
          )}
        </div>

        {divider}

        {/* ── AI Summarize ── */}
        {(() => {
          const sumUsage = user ? getDailyUsage('summarize', user.id, AI_LIMITS.summarize.daily) : { remaining: 0 }
          const noUses = !isAdmin && sumUsage.remaining <= 0
          const busy = summarizing || fixingGrammar || fixingCode
          return (
            <button
              onClick={async () => {
                if (!AI_KEY_CONFIGURED) { setAiError('AI key missing — redeploy with VITE_GEMINI_API_KEY'); setTimeout(() => setAiError(null), 8000); return }
                if (!user) { setAiError('Not signed in'); setTimeout(() => setAiError(null), 4000); return }
                if (busy || !hasText || noUses) return
                const text = editor.getText()
                const tooLong = !isAdmin && text.length > AI_LIMITS.summarize.maxChars
                if (tooLong) { setAiError(`Text too long (max ${(AI_LIMITS.summarize.maxChars / 1000).toFixed(0)}k chars)`); setTimeout(() => setAiError(null), 4000); return }
                setSummarizing(true)
                setAiError(null)
                try {
                  const summary = await summarizeText(text)
                  editor.chain().focus().insertContentAt(0, [
                    { type: 'blockquote', content: [{ type: 'paragraph', content: [{ type: 'text', marks: [{ type: 'bold' }], text: 'AI Summary: ' }, { type: 'text', text: summary }] }] },
                    { type: 'paragraph' },
                  ]).run()
                  if (!isAdmin) addDailyUsage('summarize', user.id, 1)
                } catch (err: any) {
                  console.error('[AI Summarize]', err)
                  const msg = err?.message || ''
                  setAiError(msg.includes('429') || msg.includes('uota') ? 'Rate limit — try again later' : msg.includes('API key') ? msg : 'Summarize failed')
                  setTimeout(() => setAiError(null), 6000)
                } finally {
                  setSummarizing(false)
                }
              }}
              disabled={busy}
              className={`${btn(false)} flex items-center gap-1 text-xs px-2 font-medium ${summarizing ? 'opacity-50 cursor-wait' : ''} ${noUses ? 'opacity-40' : ''}`}
              title={!AI_KEY_CONFIGURED ? 'AI key not configured' : isAdmin ? 'Summarize (unlimited)' : noUses ? '✨ Premium coming soon' : `Summarize (${sumUsage.remaining} left today)`}
            >
              {summarizing ? (
                <div className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
              ) : (
                <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2L9.19 8.63 2 9.24l5.46 4.73L5.82 21 12 17.27 18.18 21l-1.64-7.03L22 9.24l-7.19-.61z" />
                </svg>
              )}
              <span>{summarizing ? 'Summarizing...' : 'Summarize'}</span>
              {!isAdmin && <span className={`text-[10px] ${noUses ? 'text-red-400' : 'text-gray-400 dark:text-gray-500'}`}>({sumUsage.remaining})</span>}
              {isAdmin && <span className="text-[10px] text-amber-500">∞</span>}
            </button>
          )
        })()}

        {/* ── AI Grammar Fix ── */}
        {(() => {
          const gramUsage = user ? getDailyUsage('grammar', user.id, AI_LIMITS.grammar.daily) : { remaining: 0 }
          const noUses = !isAdmin && gramUsage.remaining <= 0
          const busy = fixingGrammar || summarizing || fixingCode
          return (
            <button
              onClick={async () => {
                if (!AI_KEY_CONFIGURED) { setAiError('AI key missing — redeploy with VITE_GEMINI_API_KEY'); setTimeout(() => setAiError(null), 8000); return }
                if (!user) { setAiError('Not signed in'); setTimeout(() => setAiError(null), 4000); return }
                if (busy || !hasText) return
                // Get fresh text/selection at click time — NOT during render
                const { from: f, to: t } = editor.state.selection
                const hasSel = f !== t
                const freshGramText = hasSel ? editor.state.doc.textBetween(f, t, ' ') : editor.getText()
                const tooLong = !isAdmin && freshGramText.length > AI_LIMITS.grammar.maxChars
                if (tooLong) { setAiError(`Text too long (max ${(AI_LIMITS.grammar.maxChars / 1000).toFixed(0)}k chars)`); setTimeout(() => setAiError(null), 4000); return }
                setFixingGrammar(true)
                setAiError(null)
                try {
                  const fixed = await fixGrammar(freshGramText)
                  if (hasSel) {
                    editor.chain().focus().deleteRange({ from: f, to: t }).insertContentAt(f, fixed).run()
                  } else {
                    editor.commands.setContent(fixed)
                  }
                  if (!isAdmin) addDailyUsage('grammar', user.id, 1)
                } catch (err: any) {
                  console.error('[AI Grammar]', err)
                  const msg = err?.message || ''
                  setAiError(msg.includes('429') || msg.includes('uota') ? 'Rate limit — try again later' : msg.includes('API key') ? msg : 'Grammar fix failed')
                  setTimeout(() => setAiError(null), 6000)
                } finally {
                  setFixingGrammar(false)
                }
              }}
              disabled={busy}
              className={`${btn(false)} flex items-center gap-1 text-xs px-2 font-medium ${fixingGrammar ? 'opacity-50 cursor-wait' : ''} ${!hasText ? 'opacity-40' : ''}`}
              title={!AI_KEY_CONFIGURED ? 'AI key not configured' : isAdmin ? 'Fix Grammar (unlimited)' : noUses ? '✨ Premium coming soon' : `Fix Grammar (${gramUsage.remaining} left today)`}
            >
              {fixingGrammar ? (
                <div className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
              ) : (
                <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12.45 16h2.09L9.43 3H7.57L2.46 16h2.09l1.12-3h5.64l1.14 3zm-6.02-5L8.5 5.48 10.57 11H6.43zm15.16.59l-8.09 8.09L9.83 16l-1.41 1.41 5.09 5.09L23 13l-1.41-1.41z" />
                </svg>
              )}
              <span>{fixingGrammar ? 'Fixing...' : 'Grammar'}</span>
              {!isAdmin && <span className={`text-[10px] ${noUses ? 'text-red-400' : 'text-gray-400 dark:text-gray-500'}`}>({gramUsage.remaining})</span>}
              {isAdmin && <span className="text-[10px] text-amber-500">∞</span>}
            </button>
          )
        })()}

        {/* ── AI Fix Code (only for programming language note types) ── */}
        {CODE_TYPES.includes(noteType) && (() => {
          const usage = user ? getCodeFixUsage(user.id) : { remaining: 0 }
          const noUses = !isAdmin && usage.remaining <= 0
          const anyBusy = fixingCode || summarizing || fixingGrammar
          return (
            <button
              onClick={async () => {
                if (!AI_KEY_CONFIGURED) { setAiError('AI key missing — redeploy with VITE_GEMINI_API_KEY'); setTimeout(() => setAiError(null), 8000); return }
                if (!user) { setAiError('Not signed in'); setTimeout(() => setAiError(null), 4000); return }
                if (!hasText || anyBusy || noUses) return
                const freshText = editor.getText()
                setFixingCode(true)
                setAiError(null)
                try {
                  const fixed = await fixCode(freshText, noteType)
                  editor.commands.setContent(fixed)
                  if (!isAdmin) addCodeFixUsage(user.id)
                } catch (err: any) {
                  console.error('[AI CodeFix]', err)
                  const msg = err?.message || ''
                  setAiError(msg.includes('429') || msg.includes('uota') ? 'Rate limit — try again later' : msg.includes('API key') ? msg : 'Code fix failed')
                  setTimeout(() => setAiError(null), 6000)
                } finally {
                  setFixingCode(false)
                }
              }}
              disabled={anyBusy}
              className={`${btn(false)} flex items-center gap-1 text-xs px-2 font-medium ${fixingCode ? 'opacity-50 cursor-wait' : ''} ${!hasText || noUses ? 'opacity-40' : ''}`}
              title={!AI_KEY_CONFIGURED ? 'AI key not configured' : isAdmin ? 'Fix Code (unlimited)' : noUses ? '✨ Premium coming soon' : `Fix Code (${usage.remaining} left today)`}
            >
              {fixingCode ? (
                <div className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
              ) : (
                <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z" />
                </svg>
              )}
              <span>{fixingCode ? 'Fixing...' : `Fix Code`}</span>
              {!isAdmin && <span className={`text-[10px] ${noUses ? 'text-red-400' : 'text-gray-400 dark:text-gray-500'}`}>({usage.remaining})</span>}
              {isAdmin && <span className="text-[10px] text-amber-500">∞</span>}
            </button>
          )
        })()}

        {/* ── AI Writer ── */}
        <button
          onClick={() => setShowAIWriterModal(true)}
          className={`${btn(false)} flex items-center gap-1 text-xs px-2 font-medium`}
          title="AI Writer"
        >
          <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
            <path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/>
          </svg>
          <span>AI Writer</span>
        </button>

        {aiError && (
          <span className="text-xs text-red-500 font-medium ml-1 animate-[fadeIn_0.15s_ease-out]">{aiError}</span>
        )}
      </div>

      {/* ── Modals ── */}
      {showLinkModal && <LinkModal editor={editor} onClose={() => setShowLinkModal(false)} />}
      {showVoiceModal && <VoiceRecorderModal editor={editor} onClose={() => setShowVoiceModal(false)} />}
      {showAIWriterModal && <AIWriterModal editor={editor} onClose={() => setShowAIWriterModal(false)} />}
      {showTableModal && (
        <TableInsertModal
          editor={editor}
          onClose={() => setShowTableModal(false)}
          anchorRect={tableButtonRef.current?.getBoundingClientRect()}
        />
      )}
    </>
  )
}

const EditorToolbar = memo(EditorToolbarInner)
export default EditorToolbar
