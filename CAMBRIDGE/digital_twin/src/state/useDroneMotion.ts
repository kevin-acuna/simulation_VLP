import { useCallback, useLayoutEffect, useRef, useState } from 'react'
import type { TwinConfig, WorldPosition } from '../model/types'
import {
  advanceDroneMotion, createDroneMotionState, droneMotionPosition, pauseDroneMotion,
  playDroneMotion, reconcileDroneMotion, setDroneMotionVisibility,
} from './droneMotionLifecycle'
import type { MotionChange } from './droneMotionLifecycle'

export function useDroneMotion(config: TwinConfig, onCommit: (position: WorldPosition) => void): {
  position: WorldPosition | null
  playing: boolean
  route: WorldPosition[]
  play: () => void
  pause: (positionOverride?: WorldPosition) => void
  restart: () => void
} {
  const [snapshot, setSnapshot] = useState(() => createDroneMotionState(config))
  const state = useRef(snapshot)
  const renderedState = useRef(snapshot)
  const latest = useRef({ config, onCommit })
  const mounted = useRef(false)
  const frame = useRef<number | null>(null)
  const generation = useRef(0)

  const cancelFrame = useCallback(() => {
    generation.current += 1
    if (frame.current !== null) window.cancelAnimationFrame(frame.current)
    frame.current = null
  }, [])

  const apply = useCallback((change: MotionChange) => {
    if (!mounted.current) return
    const previous = state.current
    state.current = change.state
    if (!change.state.playing) cancelFrame()
    if (previous !== change.state) setSnapshot(change.state)
    if (change.commit) latest.current.onCommit([...change.commit])
  }, [cancelFrame])

  const requestFrame = useCallback(function schedule() {
    if (!mounted.current || !state.current.playing || frame.current !== null || document.visibilityState === 'hidden') return
    const scheduledGeneration = generation.current
    frame.current = window.requestAnimationFrame((nowMs) => {
      if (!mounted.current || generation.current !== scheduledGeneration) return
      frame.current = null
      if (document.visibilityState === 'hidden') {
        state.current = setDroneMotionVisibility(state.current, false, nowMs)
        return
      }
      apply(advanceDroneMotion(state.current, nowMs))
      schedule()
    })
  }, [apply])

  const pause = useCallback((positionOverride?: WorldPosition) => {
    if (!mounted.current) return
    cancelFrame()
    apply(pauseDroneMotion(state.current, latest.current.config, positionOverride, renderedState.current))
  }, [apply, cancelFrame])

  const start = useCallback((restart: boolean) => {
    if (!mounted.current) return
    const next = playDroneMotion(state.current, latest.current.config, performance.now(), document.visibilityState !== 'hidden', restart)
    apply({ state: next, commit: null })
    requestFrame()
  }, [apply, requestFrame])

  const play = useCallback(() => start(false), [start])
  const restart = useCallback(() => start(true), [start])

  useLayoutEffect(() => {
    latest.current = { config, onCommit }
    renderedState.current = snapshot
    apply(reconcileDroneMotion(state.current, config))
  }, [config, onCommit, snapshot, apply])

  useLayoutEffect(() => {
    mounted.current = true
    const onVisibilityChange = () => {
      cancelFrame()
      const visible = document.visibilityState !== 'hidden'
      state.current = setDroneMotionVisibility(state.current, visible, performance.now())
      if (visible) requestFrame()
    }
    document.addEventListener('visibilitychange', onVisibilityChange)
    onVisibilityChange()
    return () => {
      mounted.current = false
      cancelFrame()
      state.current = setDroneMotionVisibility(state.current, false, performance.now())
      document.removeEventListener('visibilitychange', onVisibilityChange)
    }
  }, [cancelFrame, requestFrame])

  return {
    position: droneMotionPosition(snapshot),
    playing: snapshot.playing,
    route: snapshot.route.points,
    play,
    pause,
    restart,
  }
}

export default useDroneMotion
