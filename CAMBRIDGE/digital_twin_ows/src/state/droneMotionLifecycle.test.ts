import { describe, expect, it } from 'vitest'
import { createDefaultConfig } from '../model/config'
import { createMotionConfig, sampleMotionRoute } from '../model/motion'
import type { TwinConfig, WorldPosition } from '../model/types'
import {
  advanceDroneMotion, createDroneMotionState, droneMotionPosition, MOTION_FRAME_INTERVAL_MS,
  pauseDroneMotion, playDroneMotion, reconcileDroneMotion, setDroneMotionVisibility,
} from './droneMotionLifecycle'

function droneConfig(): TwinConfig {
  const config = createDefaultConfig()
  return {
    ...config,
    motion: createMotionConfig(),
    receiver: { ...config.receiver, platform: 'drone', position: [-0.7, 0.45, 0.6] },
  }
}

function withPosition(config: TwinConfig, position: WorldPosition): TwinConfig {
  return { ...config, receiver: { ...config.receiver, position: [...position] } }
}

function moving(config = droneConfig()) {
  return advanceDroneMotion(playDroneMotion(createDroneMotionState(config), config, 100, true), 1100).state
}

describe('drone motion lifecycle', () => {
  it('loads paused with a preview route and never moves a cylinder', () => {
    const config = droneConfig()
    config.receiver.platform = 'cylinder'
    const state = createDroneMotionState(config)
    expect(state.playing).toBe(false)
    expect(state.clock).toBeNull()
    expect(droneMotionPosition(state)).toBeNull()
    expect(state.route.points.length).toBeGreaterThan(1)
    expect(state.route.points[0]).toEqual(config.receiver.position)
    expect(playDroneMotion(state, config, 0, true)).toBe(state)
    expect(playDroneMotion(state, config, 0, true, true)).toBe(state)
    expect(advanceDroneMotion(state, 100000)).toEqual({ state, commit: null })
  })

  it('starts at the current pose, follows a lead-in, and preserves the same route on each tick', () => {
    const config = droneConfig()
    const idle = createDroneMotionState(config)
    const started = playDroneMotion(idle, config, 100, true)
    expect(droneMotionPosition(started)).toEqual(config.receiver.position)
    expect(sampleMotionRoute(started.route, 0, true).position).toEqual(config.receiver.position)
    expect(started.route.leadInLengthM).toBeGreaterThan(0)
    expect(started.route).toBe(idle.route)
    expect(playDroneMotion(started, config, 500, true)).toBe(started)
    const next = advanceDroneMotion(started, 1100)
    expect(next.commit).toBeNull()
    expect(next.state.distanceM).toBeCloseTo(config.motion.speedMps)
    expect(next.state.position).toEqual(sampleMotionRoute(idle.route, config.motion.speedMps, true).position)
    expect(next.state.route).toBe(idle.route)
  })

  it('samples by elapsed visible time, not the frame count, with no visible-stall delta cap', () => {
    const config = droneConfig()
    const start = playDroneMotion(createDroneMotionState(config), config, 100, true)
    let manyFrames = start
    for (let now = 150; now <= 20100; now += 50) manyFrames = advanceDroneMotion(manyFrames, now).state
    const oneStalledFrame = advanceDroneMotion(start, 20100).state
    expect(oneStalledFrame.distanceM).toBeCloseTo(20 * config.motion.speedMps)
    expect(oneStalledFrame.distanceM).toBe(manyFrames.distanceM)
    expect(oneStalledFrame.position).toEqual(manyFrames.position)
    expect(oneStalledFrame.playing).toBe(true)
  })

  it('publishes at most 30 frames per second, including on high-refresh displays', () => {
    const config = droneConfig()
    let state = playDroneMotion(createDroneMotionState(config), config, 0, true)
    const timestamps: number[] = []
    for (let now = 1; now <= 1000; now += 1) {
      const next = advanceDroneMotion(state, now)
      if (next.state !== state) timestamps.push(now)
      expect(next.commit).toBeNull()
      state = next.state
    }
    expect(timestamps.length).toBeLessThanOrEqual(30)
    expect(timestamps.length).toBeGreaterThanOrEqual(29)
    for (let index = 1; index < timestamps.length; index += 1) {
      expect(timestamps[index] - timestamps[index - 1]).toBeGreaterThanOrEqual(MOTION_FRAME_INTERVAL_MS)
    }
    expect(state.distanceM).toBeCloseTo(timestamps.at(-1)! / 1000 * config.motion.speedMps)
    expect(advanceDroneMotion(state, Number.NaN).state).toBe(state)
    expect(advanceDroneMotion(state, 0).state).toBe(state)
  })

  it('freezes the last published pose while hidden and excludes all hidden time', () => {
    const config = droneConfig()
    const before = moving(config)
    const hidden = setDroneMotionVisibility(before, false, 1120)
    expect(hidden.playing).toBe(true)
    expect(hidden.clock).toBeNull()
    expect(hidden.position).toEqual(before.position)
    expect(advanceDroneMotion(hidden, 601120).state).toBe(hidden)
    const visible = setDroneMotionVisibility(hidden, true, 601120)
    expect(visible.position).toEqual(before.position)
    expect(advanceDroneMotion(visible, 601121).state).toBe(visible)
    const after = advanceDroneMotion(visible, 602120).state
    expect(after.distanceM).toBeCloseTo(before.distanceM + config.motion.speedMps)
    expect(after.route).toBe(before.route)
    expect(setDroneMotionVisibility(after, true, 999999)).toBe(after)
  })

  it('does not start a clock when Play is requested in a hidden document', () => {
    const config = droneConfig()
    const state = playDroneMotion(createDroneMotionState(config), config, 100, false)
    expect(state.playing).toBe(true)
    expect(state.clock).toBeNull()
    expect(advanceDroneMotion(state, 100000).state).toBe(state)
    const visible = setDroneMotionVisibility(state, true, 100000)
    expect(advanceDroneMotion(visible, 101000).state.distanceM).toBeCloseTo(config.motion.speedMps)
  })

  it('pauses at the current published pose, holds it until acknowledgement, then resumes phase', () => {
    const config = droneConfig()
    const before = moving(config)
    const paused = pauseDroneMotion(before, config)
    expect(paused.commit).toEqual(before.position)
    expect(paused.state.clock).toBeNull()
    expect(paused.state.playing).toBe(false)
    expect(droneMotionPosition(paused.state)).toEqual(before.position)
    expect(advanceDroneMotion(paused.state, 900000).state).toBe(paused.state)
    expect(pauseDroneMotion(paused.state, config)).toEqual({ state: paused.state, commit: null })
    expect(reconcileDroneMotion(paused.state, config).state).toBe(paused.state)
    const acknowledgedConfig = withPosition(config, paused.commit!)
    const acknowledged = reconcileDroneMotion(paused.state, acknowledgedConfig)
    expect(acknowledged.commit).toBeNull()
    expect(droneMotionPosition(acknowledged.state)).toBeNull()
    expect(acknowledged.state.route).toBe(before.route)
    expect(acknowledged.state.distanceM).toBe(before.distanceM)
    const resumed = playDroneMotion(acknowledged.state, acknowledgedConfig, 1000000, true)
    expect(resumed.position).toEqual(paused.commit)
    const next = advanceDroneMotion(resumed, 1001000).state
    expect(next.distanceM).toBeCloseTo(before.distanceM + config.motion.speedMps)
    expect(next.route).toBe(before.route)
  })

  it('acknowledges a pause commit even when Play was pressed before the parent updated', () => {
    const config = droneConfig()
    const before = moving(config)
    const paused = pauseDroneMotion(before, config)
    const resumed = playDroneMotion(paused.state, config, 2000, true)
    const advanced = advanceDroneMotion(resumed, 2500).state
    const acknowledged = reconcileDroneMotion(advanced, withPosition(config, paused.commit!))
    expect(acknowledged.commit).toBeNull()
    expect(acknowledged.state.playing).toBe(true)
    expect(acknowledged.state.expectedCommit).toBeNull()
    expect(acknowledged.state.route).toBe(before.route)
    expect(acknowledged.state.distanceM).toBe(advanced.distanceM)
    expect(acknowledged.state.position).toEqual(advanced.position)
  })

  it('commits the exact rendered drag-start override, not a RAF-ahead pose, and rewinds its phase', () => {
    const config = droneConfig()
    const rendered = moving(config)
    const ahead = advanceDroneMotion(rendered, 1150).state
    expect(ahead.position).not.toEqual(rendered.position)
    const paused = pauseDroneMotion(ahead, config, rendered.position, rendered)
    expect(paused.commit).toEqual(rendered.position)
    expect(paused.state.position).toEqual(rendered.position)
    expect(paused.state.distanceM).toBe(rendered.distanceM)
    expect(paused.state.route).toBe(rendered.route)
    expect(paused.state.clock).toBeNull()
    const acknowledgedConfig = withPosition(config, paused.commit!)
    const acknowledged = reconcileDroneMotion(paused.state, acknowledgedConfig).state
    const resumed = playDroneMotion(acknowledged, acknowledgedConfig, 5000, true)
    expect(resumed.position).toEqual(rendered.position)
    expect(advanceDroneMotion(resumed, 5050).state.position).toEqual(ahead.position)
  })

  it('uses arbitrary pause overrides exactly and rebuilds the route rather than snapping back', () => {
    const config = droneConfig()
    const before = moving(config)
    const override: WorldPosition = [0.12, -0.34, 0.56]
    const paused = pauseDroneMotion(before, config, override)
    expect(paused.commit).toEqual(override)
    expect(paused.state.position).toEqual(override)
    expect(paused.state.route).not.toBe(before.route)
    expect(paused.state.route.points[0]).toEqual(override)
    expect(paused.state.distanceM).toBe(0)
    expect(playDroneMotion(paused.state, config, 0, true).position).toEqual(override)
  })

  it('restarts from the live current pose, not the saved pose or the old first route point', () => {
    const config = droneConfig()
    const before = moving(config)
    const restarted = playDroneMotion(before, config, 2000, true, true)
    expect(restarted.playing).toBe(true)
    expect(restarted.distanceM).toBe(0)
    expect(restarted.route).not.toBe(before.route)
    expect(restarted.position).toEqual(before.position)
    expect(restarted.route.points[0]).toEqual(before.position)
    expect(sampleMotionRoute(restarted.route, 0, true).position).toEqual(before.position)
    expect(restarted.expectedCommit).toBeNull()
  })

  const physicalEdits: [string, (config: TwinConfig) => TwinConfig][] = [
    ['pattern', (config) => ({ ...config, motion: { ...config.motion, pattern: 'circle' } })],
    ['extent', (config) => ({ ...config, motion: { ...config.motion, extentM: 0.9 } })],
    ['altitude', (config) => ({ ...config, motion: { ...config.motion, altitudeM: 0.4 } })],
    ['speed', (config) => ({ ...config, motion: { ...config.motion, speedMps: 0.5 } })],
    ['loop', (config) => ({ ...config, motion: { ...config.motion, loop: false } })],
    ['width', (config) => ({ ...config, room: { ...config.room, width: 4 } })],
    ['depth', (config) => ({ ...config, room: { ...config.room, depth: 4 } })],
    ['height', (config) => ({ ...config, room: { ...config.room, height: 3 } })],
    ['platform', (config) => ({ ...config, receiver: { ...config.receiver, platform: 'cylinder' } })],
    ['yaw', (config) => ({ ...config, receiver: { ...config.receiver, yaw: 45 } })],
  ]

  it.each(physicalEdits)('pauses and invalidates on a %s edit while retaining an unedited live pose', (_name, edit) => {
    const config = droneConfig()
    const before = moving(config)
    const next = reconcileDroneMotion(before, edit(config))
    expect(next.state.playing).toBe(false)
    expect(next.state.clock).toBeNull()
    expect(next.state.route).not.toBe(before.route)
    expect(next.state.distanceM).toBe(0)
    expect(next.commit).toEqual(before.position)
    expect(next.state.route.points[0]).toEqual(before.position)
  })

  it('lets external position edits win, even together with geometry edits or an outstanding commit', () => {
    const config = droneConfig()
    const before = moving(config)
    const external = withPosition(config, [0.2, -0.1, 0.5])
    external.room = { ...external.room, width: 4 }
    for (const state of [before, pauseDroneMotion(before, config).state]) {
      const next = reconcileDroneMotion(state, external)
      expect(next.commit).toBeNull()
      expect(next.state.playing).toBe(false)
      expect(next.state.expectedCommit).toBeNull()
      expect(next.state.position).toEqual(external.receiver.position)
      expect(next.state.route.points[0]).toEqual(external.receiver.position)
      expect(next.state.route).not.toBe(state.route)
      expect(droneMotionPosition(next.state)).toBeNull()
    }
  })

  it('does not reset on rotor, optical, lighting, palette, or display edits', () => {
    const config = droneConfig()
    const before = moving(config)
    const unrelated: TwinConfig = {
      ...config,
      receiver: { ...config.receiver, position: [...config.receiver.position], rotorsSpinning: !config.receiver.rotorsSpinning },
      room: { ...config.room },
      motion: { ...config.motion },
      optical: createDefaultConfig().optical,
      lighting: { ...config.lighting, power: 0.7 },
      appearance: { theme: 'white' },
      display: { ...config.display, grid: !config.display.grid },
    }
    expect(reconcileDroneMotion(before, unrelated)).toEqual({ state: before, commit: null })
    expect(reconcileDroneMotion(before, unrelated).state).toBe(before)
  })

  it('finishes finite routes once, holds the endpoint until acknowledged, and can start again', () => {
    const config = droneConfig()
    config.motion.loop = false
    const before = playDroneMotion(createDroneMotionState(config), config, 100, true)
    const finished = advanceDroneMotion(before, 100 + before.route.lengthM / config.motion.speedMps * 1000 + 100)
    expect(finished.state.playing).toBe(false)
    expect(finished.state.completed).toBe(true)
    expect(finished.state.clock).toBeNull()
    expect(finished.state.distanceM).toBe(before.route.lengthM)
    expect(finished.commit).toEqual(before.route.points.at(-1))
    expect(droneMotionPosition(finished.state)).toEqual(finished.commit)
    expect(advanceDroneMotion(finished.state, 999999).commit).toBeNull()
    const acknowledgedConfig = withPosition(config, finished.commit!)
    const acknowledged = reconcileDroneMotion(finished.state, acknowledgedConfig).state
    expect(droneMotionPosition(acknowledged)).toBeNull()
    const again = playDroneMotion(acknowledged, acknowledgedConfig, 1000000, true)
    expect(again.playing).toBe(true)
    expect(again.distanceM).toBe(0)
    expect(again.route).not.toBe(before.route)
    expect(again.route.points[0]).toEqual(finished.commit)
  })

  it('loops the pattern without ever replaying its lead-in', () => {
    const config = droneConfig()
    const started = playDroneMotion(createDroneMotionState(config), config, 0, true)
    const { leadInLengthM, loopLengthM } = started.route
    const firstDistance = leadInLengthM + loopLengthM * 0.25
    const repeatedDistance = firstDistance + loopLengthM * 3
    const first = advanceDroneMotion(started, firstDistance / config.motion.speedMps * 1000)
    const repeated = advanceDroneMotion(started, repeatedDistance / config.motion.speedMps * 1000)
    first.state.position.forEach((value, index) => expect(repeated.state.position[index]).toBeCloseTo(value, 9))
    expect(repeated.state.playing).toBe(true)
    expect(repeated.commit).toBeNull()
  })
})
