import { useEffect, useState, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from '../context/AuthContext'
import type { Folder } from '../types'

export function useFolders() {
  const { user } = useAuth()
  const [folders, setFolders] = useState<Folder[]>([])
  const [loading, setLoading] = useState(true)

  const fetchFolders = useCallback(async (silent = false) => {
    if (!user) return
    if (!silent) setLoading(true)
    const { data, error } = await supabase
      .from('folders')
      .select('*')
      .eq('user_id', user.id)
      .order('name', { ascending: true })
    if (!error && data) setFolders(data as Folder[])
    setLoading(false)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id])

  useEffect(() => {
    fetchFolders()
  }, [fetchFolders])

  useEffect(() => {
    if (!user) return

    const channel = supabase
      .channel('folders-realtime')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'folders',
          filter: `user_id=eq.${user.id}`,
        },
        (payload) => {
          if (payload.eventType === 'INSERT') {
            setFolders(prev => {
              if (prev.some(f => f.id === (payload.new as Folder).id)) return prev
              return [...prev, payload.new as Folder].sort((a, b) => a.name.localeCompare(b.name))
            })
          } else if (payload.eventType === 'UPDATE') {
            setFolders(prev =>
              prev.map(f => (f.id === (payload.new as Folder).id ? (payload.new as Folder) : f))
                .sort((a, b) => a.name.localeCompare(b.name))
            )
          } else if (payload.eventType === 'DELETE') {
            setFolders(prev => prev.filter(f => f.id !== (payload.old as Folder).id))
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id])

  // Refetch when tab becomes visible again (handles missed realtime events during sleep/background)
  useEffect(() => {
    const handleVisibility = () => {
      if (document.visibilityState === 'visible') fetchFolders(true)
    }
    document.addEventListener('visibilitychange', handleVisibility)
    return () => document.removeEventListener('visibilitychange', handleVisibility)
  }, [fetchFolders])

  const createFolder = async (name: string) => {
    if (!user) return
    const { error } = await supabase.from('folders').insert({
      user_id: user.id,
      name,
    })
    return { error }
  }

  const renameFolder = async (id: string, name: string) => {
    setFolders(prev => prev.map(f => f.id === id ? { ...f, name } : f))
    const { error } = await supabase.from('folders').update({ name }).eq('id', id)
    if (error) fetchFolders()
    return { error }
  }

  const deleteFolder = async (id: string) => {
    setFolders(prev => prev.filter(f => f.id !== id))
    await supabase.from('notes').delete().eq('folder_id', id)
    const { error } = await supabase.from('folders').delete().eq('id', id)
    if (error) fetchFolders()
    return { error }
  }

  const updateFolderColor = async (id: string, color: string | null) => {
    setFolders(prev => prev.map(f => f.id === id ? { ...f, color } : f))
    const { error } = await supabase.from('folders').update({ color } as Record<string, unknown>).eq('id', id)
    if (error) fetchFolders()
    return { error }
  }

  return { folders, loading, createFolder, renameFolder, deleteFolder, updateFolderColor }
}
