import { buildMotionRoute, sampleMotionRoute } from '../model/motion'
import type { MotionRoute } from '../model/motion'
import { clampReceiverPosition } from '../model/receiver'
import type { TwinConfig, WorldPosition } from '../model/types'

export const MOTION_FRAME_INTERVAL_MS = 1000 / 30

interface MotionClock {
  startedAtMs: number
  distanceAtStartM: number
  publishedAtMs: number
}

export interface DroneMotionState {
  parametersKey: string
  configuredPosition: WorldPosition
  route: MotionRoute
  position: WorldPosition
  distanceM: number
  speedMps: number
  loop: boolean
  playing: boolean
  completed: boolean
  expectedCommit: WorldPosition | null
  clock: MotionClock | null
}

export interface MotionChange {
  state: DroneMotionState
  commit: WorldPosition | null
}

export function sameMotionPosition(a: WorldPosition, b: WorldPosition): boolean {
  return a.every((value, index) => value === b[index])
}

function parametersKey(config: TwinConfig): string {
  const { room, receiver, motion } = config
  return JSON.stringify([
    room.width, room.depth, room.height, receiver.platform, receiver.yaw,
    motion.pattern, motion.extentM, motion.altitudeM, motion.speedMps, motion.loop,
  ])
}

export function createDroneMotionState(config: TwinConfig, start: WorldPosition = config.receiver.position): DroneMotionState {
  const route = buildMotionRoute(config.room, config.receiver, config.motion, start)
  return {
    parametersKey: parametersKey(config),
    configuredPosition: [...config.receiver.position],
    route,
    position: [...start],
    distanceM: 0,
    speedMps: config.motion.speedMps,
    loop: config.motion.loop,
    playing: false,
    completed: false,
    expectedCommit: null,
    clock: null,
  }
}

function withCommit(state: DroneMotionState, position: WorldPosition): MotionChange {
  const committed: WorldPosition = [...position]
  return {
    state: {
      ...state,
      position: [...committed],
      expectedCommit: sameMotionPosition(committed, state.configuredPosition) ? null : committed,
    },
    commit: committed,
  }
}

export function reconcileDroneMotion(state: DroneMotionState, config: TwinConfig): MotionChange {
  const key = parametersKey(config)
  const positionChanged = !sameMotionPosition(config.receiver.position, state.configuredPosition)
  const acknowledged = state.expectedCommit !== null && sameMotionPosition(config.receiver.position, state.expectedCommit)
  const externallyPositioned = positionChanged && !acknowledged

  if (key !== state.parametersKey || externallyPositioned) {
    const retainLivePosition = !externallyPositioned && (state.playing || state.expectedCommit !== null)
    const start = retainLivePosition
      ? clampReceiverPosition(state.position, config.room, config.receiver.platform, config.receiver.yaw)
      : config.receiver.position
    const next = createDroneMotionState(config, start)
    return retainLivePosition && !sameMotionPosition(start, config.receiver.position)
      ? withCommit(next, start)
      : { state: next, commit: null }
  }

  if (positionChanged || acknowledged) {
    return {
      state: { ...state, configuredPosition: [...config.receiver.position], expectedCommit: acknowledged ? null : state.expectedCommit },
      commit: null,
    }
  }
  return { state, commit: null }
}

export function playDroneMotion(
  state: DroneMotionState,
  config: TwinConfig,
  nowMs: number,
  visible: boolean,
  restart = false,
): DroneMotionState {
  if (config.receiver.platform !== 'drone' || (state.playing && !restart)) return state
  const rebuild = restart || state.completed
  const route = rebuild ? buildMotionRoute(config.room, config.receiver, config.motion, state.position) : state.route
  const distanceM = rebuild ? 0 : state.distanceM
  return {
    ...state,
    route,
    distanceM,
    playing: true,
    completed: false,
    clock: visible ? { startedAtMs: nowMs, distanceAtStartM: distanceM, publishedAtMs: nowMs } : null,
  }
}

export function pauseDroneMotion(
  state: DroneMotionState,
  config: TwinConfig,
  positionOverride?: WorldPosition,
  renderedState?: DroneMotionState,
): MotionChange {
  if (!state.playing && !positionOverride) return { state, commit: null }
  const position = positionOverride ?? state.position
  let distanceM = state.distanceM
  let route = state.route
  let completed = state.completed
  if (!sameMotionPosition(position, state.position)) {
    if (renderedState?.route === route && sameMotionPosition(position, renderedState.position)) {
      distanceM = renderedState.distanceM
      completed = renderedState.completed
    } else {
      route = buildMotionRoute(config.room, config.receiver, config.motion, position)
      distanceM = 0
      completed = false
    }
  }
  return withCommit({ ...state, route, distanceM, completed, playing: false, clock: null }, position)
}

export function setDroneMotionVisibility(state: DroneMotionState, visible: boolean, nowMs: number): DroneMotionState {
  if (!state.playing || (visible && state.clock !== null) || (!visible && state.clock === null)) return state
  return {
    ...state,
    clock: visible ? { startedAtMs: nowMs, distanceAtStartM: state.distanceM, publishedAtMs: nowMs } : null,
  }
}

export function advanceDroneMotion(state: DroneMotionState, nowMs: number): MotionChange {
  if (!state.playing || state.clock === null || !Number.isFinite(nowMs)) return { state, commit: null }
  if (nowMs - state.clock.publishedAtMs < MOTION_FRAME_INTERVAL_MS) return { state, commit: null }
  const distanceM = state.clock.distanceAtStartM + Math.max(0, nowMs - state.clock.startedAtMs) / 1000 * state.speedMps
  const sample = sampleMotionRoute(state.route, distanceM, state.loop)
  const next: DroneMotionState = {
    ...state,
    position: sample.position,
    distanceM: sample.done ? state.route.lengthM : distanceM,
    playing: !sample.done,
    completed: sample.done,
    clock: sample.done ? null : { ...state.clock, publishedAtMs: nowMs },
  }
  return sample.done ? withCommit(next, sample.position) : { state: next, commit: null }
}

export function droneMotionPosition(state: DroneMotionState): WorldPosition | null {
  return state.playing || state.expectedCommit !== null ? state.position : null
}
