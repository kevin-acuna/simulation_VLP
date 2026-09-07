import { lazy, Suspense, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Activity, Box, Camera, Grid2X2, Map, Maximize, Pause, Play, RotateCcw, Ruler, Square, Layers3, SlidersHorizontal } from 'lucide-react'
import type { CSSProperties } from 'react'
import { getFixtures } from './model/config'
import { getReceiverGeometry, RECEIVER_ID } from './model/receiver'
import { getThemeVariables } from './theme/themes'
import { useTwinConfig } from './state/useTwinConfig'
import ControlPanel from './components/ControlPanel'
import RssPanel from './components/RssPanel'
import PlanPanel from './components/PlanPanel'
import { useDroneMotion } from './state/useDroneMotion'
import { toOpticalScene } from './model/opticalScene'
import { MODEL_ASSUMPTIONS, MODEL_ID } from './science'
import SceneBoundary from './components/SceneBoundary'
import type { PanelTab } from './components/ControlPanel'
import type { CameraFraming, CameraView, WorldPosition } from './model/types'

const TestbedScene = lazy(() => import('./scene/TestbedScene'))

export default function App() {
  const { config, updateConfig, saved, resetConfig } = useTwinConfig()
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [receiverDraft, setReceiverDraft] = useState<WorldPosition | null>(null)
  const [receiverDragging, setReceiverDragging] = useState(false)
  const [tab, setTab] = useState<PanelTab>('room')
  const [view, setView] = useState<CameraView>('isometric')
  const [cameraReset, setCameraReset] = useState(0)
  const [framing, setFraming] = useState<CameraFraming>('immersive')
  const [exported, setExported] = useState(false)
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [rssOpen, setRssOpen] = useState(false)
  const [planOpen, setPlanOpen] = useState(false)
  const settingsButton = useRef<HTMLButtonElement>(null)
  const rssButton = useRef<HTMLButtonElement>(null)
  const planButton = useRef<HTMLButtonElement>(null)
  const droneMotion = useDroneMotion(config, (position) => updateConfig((previous) => ({ ...previous, receiver: { ...previous.receiver, position } })))
  const fixtures = useMemo(() => getFixtures(config), [config])
  const livePosition = receiverDraft ?? droneMotion.position
  const liveConfig = useMemo(() => livePosition ? { ...config, receiver: { ...config.receiver, position: livePosition } } : config, [config, livePosition])
  const opticalScene = useMemo(() => toOpticalScene(liveConfig), [liveConfig])
  const activeId = selectedId === RECEIVER_ID || fixtures.some((fixture) => fixture.id === selectedId) ? selectedId : null
  const closeSettings = useCallback(() => {
    setSettingsOpen(false)
    settingsButton.current?.focus({ preventScroll: true })
  }, [])
  const closeRss = useCallback(() => {
    setRssOpen(false)
    rssButton.current?.focus({ preventScroll: true })
  }, [])
  const closePlan = useCallback(() => {
    setPlanOpen(false)
    planButton.current?.focus({ preventScroll: true })
  }, [])

  function openOpticalSettings() {
    setTab('optics')
    setSettingsOpen(true)
  }

  useEffect(() => {
    if (!settingsOpen) return
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') closeSettings()
    }
    window.addEventListener('keydown', handleEscape)
    return () => window.removeEventListener('keydown', handleEscape)
  }, [settingsOpen, closeSettings])

  function selectObject(id: string | null, inspect = true) {
    setSelectedId(id)
    if (id) {
      setTab(id === RECEIVER_ID ? 'receiver' : 'lighting')
      if (inspect) setSettingsOpen(true)
    }
  }
  function selectTab(nextTab: PanelTab) {
    setTab(nextTab)
    if (nextTab === 'receiver') setSelectedId(RECEIVER_ID)
  }
  function beginReceiverDrag(position: WorldPosition) {
    droneMotion.pause(position)
    setReceiverDragging(true)
  }
  function commitReceiver(position: WorldPosition | null) {
    if (position) updateConfig((previous) => ({ ...previous, receiver: { ...previous.receiver, position } }))
    setReceiverDraft(null)
    setReceiverDragging(false)
  }
  function playDroneRoute(restart = false) {
    if (config.receiver.platform !== 'drone' || receiverDragging) return
    if (!config.receiver.rotorsSpinning) updateConfig((previous) => ({ ...previous, receiver: { ...previous.receiver, rotorsSpinning: true } }))
    if (restart) droneMotion.restart()
    else droneMotion.play()
  }
  function pauseDroneRoute() {
    droneMotion.pause(liveConfig.receiver.position)
  }
  function resetCamera(nextView: CameraView = view, nextFraming: CameraFraming = nextView === 'isometric' || nextView === 'perspective' ? 'immersive' : 'fit') {
    setView(nextView)
    setFraming(nextFraming)
    setCameraReset((previous) => previous + 1)
  }
  function exportScene() {
    const snapshot = liveConfig
    const blob = new Blob([JSON.stringify({ schemaVersion: 1, coordinateSystem: 'right-handed, Z-up, metres', receiverGeometry: getReceiverGeometry(snapshot.receiver.platform), opticalModel: MODEL_ID, opticalAssumptions: MODEL_ASSUMPTIONS, opticalScene: toOpticalScene(snapshot), config: snapshot }, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = 'cambridge-testbed.json'
    link.click()
    window.setTimeout(() => URL.revokeObjectURL(url), 1000)
    setExported(true)
    window.setTimeout(() => setExported(false), 2200)
  }
  function resetScene() {
    droneMotion.pause()
    resetConfig()
    setReceiverDraft(null)
    setReceiverDragging(false)
    setSelectedId(null)
    resetCamera('isometric')
  }

  return (
    <div className="app-shell" data-theme={config.appearance.theme} style={getThemeVariables(config.appearance.theme) as CSSProperties}>
      <main className="main-layout">
        <section className="workspace" aria-label="Interactive 3D testbed">
          <div className="scene-viewport" data-testid="scene-viewport">
            <SceneBoundary><Suspense fallback={<div className="scene-loading"><Box size={28} /><span>Building your environment…</span></div>}><TestbedScene config={liveConfig} fixtures={fixtures} selectedId={activeId} onSelect={selectObject} onReceiverPreview={setReceiverDraft} onReceiverCommit={commitReceiver} onReceiverDragStart={beginReceiverDrag} view={view} cameraReset={cameraReset} framing={framing} /></Suspense></SceneBoundary>
          </div>
          <button ref={settingsButton} className={`settings-toggle${settingsOpen ? ' active' : ''}`} aria-label={settingsOpen ? 'Close settings' : 'Open settings'} title={settingsOpen ? 'Close settings' : 'Scene settings'} aria-expanded={settingsOpen} aria-controls="scene-settings" onClick={() => settingsOpen ? closeSettings() : setSettingsOpen(true)}><SlidersHorizontal size={19} /></button>
          <div className="analysis-toggles">
            <button ref={rssButton} className={`rss-toggle${rssOpen ? ' active' : ''}`} aria-label={rssOpen ? 'Hide RSS chart' : 'Open RSS chart'} title="Received optical power" aria-expanded={rssOpen} onClick={() => rssOpen ? closeRss() : setRssOpen(true)}><Activity size={18} /><span>RSS</span></button>
            <button ref={planButton} className={`plan-toggle${planOpen ? ' active' : ''}`} aria-label={planOpen ? 'Hide X-Y plan' : 'Open X-Y plan'} title="X-Y positions" aria-expanded={planOpen} onClick={() => planOpen ? closePlan() : setPlanOpen(true)}><Map size={18} /><span>X–Y</span></button>
          </div>
          <div className="analysis-panels" data-panel-count={Number(planOpen) + Number(rssOpen)}>
            {planOpen && <PlanPanel room={liveConfig.room} fixtures={fixtures} receiver={liveConfig.receiver} path={config.receiver.platform === 'drone' ? droneMotion.route : []} onClose={closePlan} />}
            {rssOpen && <RssPanel scene={opticalScene} parameters={liveConfig.optical} onClose={closeRss} onSettings={openOpticalSettings} />}
          </div>
          <div className="workspace-bottom">
            <div className="viewport-toolbar" role="toolbar" aria-label="Camera and display controls">
              <div className="view-buttons">
                <button className={view === 'perspective' ? 'active' : ''} onClick={() => resetCamera('perspective')} title="Perspective · interior view" aria-label="Perspective view" aria-pressed={view === 'perspective'}><Camera size={17} /><span>Perspective</span></button>
                <button className={view === 'isometric' ? 'active' : ''} onClick={() => resetCamera('isometric')} title="Isometric view" aria-label="Isometric view" aria-pressed={view === 'isometric'}><Box size={17} /><span>Isometric</span></button>
                <button className={view === 'top' ? 'active' : ''} onClick={() => resetCamera('top')} title="Top view" aria-label="Top view" aria-pressed={view === 'top'}><Layers3 size={17} /></button>
                <button className={view === 'front' ? 'active' : ''} onClick={() => resetCamera('front')} title="Front view" aria-label="Front view" aria-pressed={view === 'front'}><Square size={16} /></button>
              </div>
              <span className="toolbar-divider" />
              <button aria-label="Toggle floor grid" title="Toggle floor grid" aria-pressed={config.display.grid} className={config.display.grid ? 'active' : ''} onClick={() => updateConfig((previous) => ({ ...previous, display: { ...previous.display, grid: !previous.display.grid } }))}><Grid2X2 size={17} /></button>
              <button aria-label="Toggle dimensions" title={view === 'perspective' ? 'Dimension guides are available in exterior views' : 'Toggle dimensions'} disabled={view === 'perspective'} aria-pressed={view !== 'perspective' && config.display.dimensions} className={view !== 'perspective' && config.display.dimensions ? 'active' : ''} onClick={() => updateConfig((previous) => ({ ...previous, display: { ...previous.display, dimensions: !previous.display.dimensions } }))}><Ruler size={17} /></button>
              <span className="toolbar-divider" />
              <button className={`motion-play${droneMotion.playing ? ' active' : ''}`} aria-label={droneMotion.playing ? 'Pause drone route' : 'Play drone route'} title={config.receiver.platform === 'drone' ? (droneMotion.playing ? 'Pause drone route' : 'Play configured drone route') : 'Choose Drone in Receiver settings to play a route'} disabled={config.receiver.platform !== 'drone' || receiverDragging} aria-pressed={droneMotion.playing} onClick={() => droneMotion.playing ? pauseDroneRoute() : playDroneRoute()}>{droneMotion.playing ? <Pause size={17} /> : <Play size={17} />}</button>
              <button onClick={() => resetCamera(view, 'fit')} aria-label="Fit room to view" title="Fit room to view"><Maximize size={17} /></button>
              <button onClick={() => resetCamera(view)} aria-label="Reset camera" title="Reset current view"><RotateCcw size={16} /></button>
            </div>
          </div>
          {settingsOpen && <ControlPanel config={liveConfig} fixtures={fixtures} selectedId={activeId} tab={tab} onTab={selectTab} onSelect={selectObject} onUpdate={updateConfig} onReset={resetScene} onClose={closeSettings} onExport={exportScene} exported={exported} saved={saved} interior={view === 'perspective'} motionPlaying={droneMotion.playing} onPlayMotion={() => playDroneRoute()} onPauseMotion={pauseDroneRoute} onRestartMotion={() => playDroneRoute(true)} />}
        </section>
      </main>
    </div>
  )
}
