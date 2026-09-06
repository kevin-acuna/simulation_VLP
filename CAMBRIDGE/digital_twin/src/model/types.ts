export type LedShape = 'circular' | 'square'
export type LedLayout = 'grid' | 'ring' | 'line'
export type CameraView = 'isometric' | 'top' | 'front' | 'perspective'
export type CameraFraming = 'immersive' | 'fit'
export type ThemeId = 'sage' | 'chalk' | 'sand' | 'mist' | 'white' | 'rose'
export type WorldPosition = [x: number, y: number, z: number]

export interface RoomConfig {
  width: number
  depth: number
  height: number
}

export interface LightingConfig {
  count: number
  shape: LedShape
  layout: LedLayout
  power: number
  temperature: number
  spacing: number
}

export interface DisplayConfig {
  grid: boolean
  dimensions: boolean
  labels: boolean
  beams: boolean
  ceiling: boolean
}

export interface TwinConfig {
  room: RoomConfig
  lighting: LightingConfig
  positions: Record<string, [number, number]>
  display: DisplayConfig
  appearance: { theme: ThemeId }
}

export interface LedFixture {
  id: string
  position: WorldPosition
  shape: LedShape
  power: number
  temperature: number
}

export interface SceneProps {
  config: TwinConfig
  fixtures: LedFixture[]
  selectedId: string | null
  onSelect: (id: string | null) => void
  view: CameraView
  cameraReset: number
  framing: CameraFraming
}
