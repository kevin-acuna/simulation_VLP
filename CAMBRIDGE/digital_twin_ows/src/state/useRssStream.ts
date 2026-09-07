import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { createGaussianGenerator, sampleRss } from '../science'
import type { NoiseParameters, OpticalScene, RssChannel } from '../science/types'
import { opticalScenarioKey } from '../model/opticalScene'

export interface RssSample {
  time: number
  channels: RssChannel[]
}

export function appendRssSample(history: RssSample[], sample: RssSample): RssSample[] {
  return [...history.filter((entry) => entry.time >= sample.time - 20), sample].slice(-401)
}

export function useRssStream(scene: OpticalScene, noise: NoiseParameters) {
  const [paused, setPaused] = useState(false)
  const [visible, setVisible] = useState(() => document.visibilityState !== 'hidden')
  const [generation, setGeneration] = useState(0)
  const [data, setData] = useState<{ samples: RssSample[]; error: string | null }>({ samples: [], error: null })
  const latest = useRef({ scene, noise })
  const gaussian = useRef<() => number>(() => 0)
  const elapsed = useRef(0)
  const lastTick = useRef<number | null>(null)
  const scenarioKey = opticalScenarioKey(scene, noise)

  useLayoutEffect(() => { latest.current = { scene, noise } }, [scene, noise])

  const takeSample = useCallback((reset = false) => {
    const current = latest.current
    const now = performance.now()
    if (reset) {
      gaussian.current = createGaussianGenerator(current.noise.seed)
      elapsed.current = 0
    } else if (lastTick.current !== null) {
      elapsed.current += Math.max(0, now - lastTick.current) / 1000
    }
    lastTick.current = now
    try {
      const sample = { time: elapsed.current, channels: sampleRss(current.scene, current.noise, gaussian.current) }
      setData((previous) => ({ samples: reset ? [sample] : appendRssSample(previous.samples, sample), error: null }))
    } catch (error) {
      setData({ samples: [], error: error instanceof Error ? error.message : 'Unable to evaluate the optical model.' })
    }
  }, [])

  useEffect(() => {
    takeSample(true)
  }, [scenarioKey, generation, takeSample])

  useEffect(() => {
    const onVisibilityChange = () => setVisible(document.visibilityState !== 'hidden')
    document.addEventListener('visibilitychange', onVisibilityChange)
    return () => document.removeEventListener('visibilitychange', onVisibilityChange)
  }, [])

  useEffect(() => {
    lastTick.current = null
    if (paused || !visible) return
    lastTick.current = performance.now()
    const timer = window.setInterval(() => takeSample(), 50)
    return () => window.clearInterval(timer)
  }, [paused, visible, scenarioKey, takeSample])

  const clear = useCallback(() => setGeneration((previous) => previous + 1), [])
  return { ...data, paused, setPaused, clear }
}
