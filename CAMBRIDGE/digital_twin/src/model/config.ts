import { DEFAULT_THEME, isThemeId } from '../theme/themes'
import type { LedFixture, TwinConfig, WorldPosition } from './types'

export const STORAGE_KEY = 'cambridge-digital-twin:v1'

const FIXTURE_CLEARANCE = 0.22
const GRID_ROWS = [
  [1],
  [2],
  [3],
  [2, 2],
  [2, 1, 2],
  [3, 3],
  [2, 3, 2],
  [3, 2, 3],
  [3, 3, 3],
]

export function createDefaultConfig(): TwinConfig {
  return {
    room: { width: 3, depth: 3, height: 2 },
    lighting: {
      count: 4,
      shape: 'circular',
      layout: 'grid',
      power: 0.405,
      temperature: 4500,
      spacing: 0.5,
    },
    positions: {},
    display: {
      grid: false,
      dimensions: true,
      labels: true,
      beams: false,
      ceiling: false,
    },
    appearance: { theme: DEFAULT_THEME },
  }
}

function record(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {}
}

function own(source: Record<string, unknown>, key: string): unknown {
  return Object.prototype.hasOwnProperty.call(source, key) ? source[key] : undefined
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value))
}

function finiteNumber(value: unknown, fallback: number, minimum: number, maximum: number): number {
  return typeof value === 'number' && Number.isFinite(value)
    ? clamp(value, minimum, maximum)
    : fallback
}

function boolean(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback
}

function fixtureId(index: number): string {
  return `LED-${String(index + 1).padStart(2, '0')}`
}

export function normalizeConfig(input: unknown): TwinConfig {
  const result = createDefaultConfig()
  const source = record(input)
  const room = record(own(source, 'room'))
  const lighting = record(own(source, 'lighting'))
  const display = record(own(source, 'display'))
  const positions = record(own(source, 'positions'))
  const appearance = record(own(source, 'appearance'))
  const theme = own(appearance, 'theme')
  if (theme === 'lavender') result.appearance.theme = 'white'
  else if (isThemeId(theme)) result.appearance.theme = theme

  result.room.width = finiteNumber(own(room, 'width'), result.room.width, 2, 10)
  result.room.depth = finiteNumber(own(room, 'depth'), result.room.depth, 2, 10)
  result.room.height = finiteNumber(own(room, 'height'), result.room.height, 1.8, 5)

  result.lighting.count = Math.round(finiteNumber(own(lighting, 'count'), result.lighting.count, 1, 9))
  result.lighting.power = finiteNumber(own(lighting, 'power'), result.lighting.power, 0, 2)
  result.lighting.temperature = finiteNumber(own(lighting, 'temperature'), result.lighting.temperature, 2700, 6500)
  result.lighting.spacing = finiteNumber(own(lighting, 'spacing'), result.lighting.spacing, 0.2, 0.8)

  const shape = own(lighting, 'shape')
  if (shape === 'circular' || shape === 'square') result.lighting.shape = shape
  const layout = own(lighting, 'layout')
  if (layout === 'grid' || layout === 'ring' || layout === 'line') result.lighting.layout = layout

  result.display.grid = boolean(own(display, 'grid'), result.display.grid)
  result.display.dimensions = boolean(own(display, 'dimensions'), result.display.dimensions)
  result.display.labels = boolean(own(display, 'labels'), result.display.labels)
  result.display.beams = boolean(own(display, 'beams'), result.display.beams)
  result.display.ceiling = boolean(own(display, 'ceiling'), result.display.ceiling)

  const limitX = result.room.width / 2 - FIXTURE_CLEARANCE
  const limitY = result.room.depth / 2 - FIXTURE_CLEARANCE
  for (let index = 0; index < result.lighting.count; index += 1) {
    const id = fixtureId(index)
    const position = own(positions, id)
    if (!Array.isArray(position) || position.length !== 2) continue
    const [x, y] = position
    if (typeof x !== 'number' || typeof y !== 'number' || !Number.isFinite(x) || !Number.isFinite(y)) continue
    result.positions[id] = [clamp(x, -limitX, limitX), clamp(y, -limitY, limitY)]
  }

  return result
}

function axisPosition(index: number, count: number, extent: number): number {
  return count === 1 ? 0 : (2 * index / (count - 1) - 1) * extent
}

function layoutPositions(config: TwinConfig): [number, number][] {
  const { room, lighting } = config
  const extentX = Math.min(room.width * lighting.spacing / 2, room.width / 2 - FIXTURE_CLEARANCE)
  const extentY = Math.min(room.depth * lighting.spacing / 2, room.depth / 2 - FIXTURE_CLEARANCE)

  if (lighting.count === 1) return [[0, 0]]

  if (lighting.layout === 'line') {
    return Array.from({ length: lighting.count }, (_, index) => [axisPosition(index, lighting.count, extentX), 0])
  }

  if (lighting.layout === 'ring') {
    const radius = Math.min(extentX, extentY)
    return Array.from({ length: lighting.count }, (_, index) => {
      const angle = 2 * Math.PI * index / lighting.count
      return [radius * Math.cos(angle), radius * Math.sin(angle)]
    })
  }

  const rows = GRID_ROWS[lighting.count - 1]
  return rows.flatMap((columns, row) => Array.from({ length: columns }, (_, column) => [
    axisPosition(column, columns, extentX),
    axisPosition(row, rows.length, extentY),
  ] as [number, number]))
}

export function getFixtures(config: TwinConfig): LedFixture[] {
  const normalized = normalizeConfig(config)
  return layoutPositions(normalized).map((position, index) => {
    const id = fixtureId(index)
    const [x, y] = normalized.positions[id] ?? position
    return {
      id,
      position: [x, y, normalized.room.height],
      shape: normalized.lighting.shape,
      power: normalized.lighting.power,
      temperature: normalized.lighting.temperature,
    }
  })
}

export function toScenePosition(world: WorldPosition): [number, number, number] {
  const [x, y, z] = world
  return [x, z, -y]
}

export function getTotalPower(config: TwinConfig): number {
  const { lighting } = normalizeConfig(config)
  return lighting.count * lighting.power
}
