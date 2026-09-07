import { Circle, Infinity, Pause, Play, RotateCcw, ScanLine } from 'lucide-react'
import { Choice, RangeField, Toggle } from './Controls'
import { getReceiverBounds } from '../model/receiver'
import type { MotionConfig, MotionPattern, TwinConfig } from '../model/types'

interface MotionSettingsProps {
  config: TwinConfig
  onUpdate: (updater: (previous: TwinConfig) => TwinConfig) => void
  playing: boolean
  onPlay: () => void
  onPause: () => void
  onRestart: () => void
}

export default function MotionSettings({ config, onUpdate, playing, onPlay, onPause, onRestart }: MotionSettingsProps) {
  const { motion, receiver, room } = config
  const bounds = getReceiverBounds(room, receiver.platform, receiver.yaw)

  function updateMotion(changes: Partial<MotionConfig>) {
    onPause()
    onUpdate((previous) => ({ ...previous, motion: { ...previous.motion, ...changes } }))
  }

  return (
    <section className="control-section motion-settings">
      <Choice<MotionPattern> label="Drone route" value={motion.pattern} options={[
        { value: 'circle', label: 'Circle', icon: <Circle size={20} /> },
        { value: 'figure-eight', label: 'Figure eight', icon: <Infinity size={20} /> },
        { value: 'raster', label: 'Raster scan', icon: <ScanLine size={20} /> },
      ]} onChange={(pattern) => updateMotion({ pattern })} />
      <p className="section-description">Routes are centred in the room and adapt to room limits. Route size is the requested half-width; flight speed is constant along the path (arc length).</p>
      <RangeField label="Route size" value={motion.extentM} min={0.1} max={4} step={0.05} digits={2} unit="m" onChange={(extentM) => updateMotion({ extentM })} />
      <RangeField label="Flight altitude" value={motion.altitudeM} min={bounds.z[0]} max={bounds.z[1]} step={0.01} digits={2} unit="m" onChange={(altitudeM) => updateMotion({ altitudeM })} />
      <RangeField label="Flight speed" value={motion.speedMps} min={0.05} max={1} step={0.05} digits={2} unit="m/s" onChange={(speedMps) => updateMotion({ speedMps })} />
      <Toggle label="Repeat route" description="Keep flying the route until paused." checked={motion.loop} onChange={(loop) => updateMotion({ loop })} />
      <p className="helper">Flight altitude is independent of manual Z. Play and Restart lead in from the current pose without jumping. Editing route options pauses playback and keeps the current pose; choosing a route does not start it.</p>
      <div className="motion-actions">
        <button type="button" className="secondary-button" onClick={playing ? onPause : onPlay}>
          {playing ? <Pause size={14} /> : <Play size={14} />}{playing ? 'Pause drone route' : 'Play drone route'}
        </button>
        <button type="button" className="secondary-button" onClick={onRestart}><RotateCcw size={14} />Restart drone route</button>
      </div>
    </section>
  )
}
