import { useEffect, useState } from 'react'
import { createDefaultConfig, normalizeConfig, STORAGE_KEY } from '../model/config'
import type { TwinConfig } from '../model/types'

function loadConfig(): TwinConfig {
  try {
    const stored = localStorage.getItem(STORAGE_KEY)
    return stored ? normalizeConfig(JSON.parse(stored)) : createDefaultConfig()
  } catch {
    return createDefaultConfig()
  }
}

export function useTwinConfig() {
  const [config, setConfig] = useState(loadConfig)
  const [saved, setSaved] = useState(false)

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(config))
      setSaved(true)
    } catch {
      setSaved(false)
    }
  }, [config])

  function updateConfig(update: (previous: TwinConfig) => TwinConfig) {
    setConfig((previous) => normalizeConfig(update(previous)))
  }

  return { config, updateConfig, saved, resetConfig: () => setConfig(createDefaultConfig()) }
}
