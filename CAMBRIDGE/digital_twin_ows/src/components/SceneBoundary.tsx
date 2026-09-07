import { Component } from 'react'
import { MonitorOff } from 'lucide-react'
import type { ErrorInfo, ReactNode } from 'react'

export default class SceneBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false }

  static getDerivedStateFromError() {
    return { failed: true }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Unable to render the testbed scene.', error, info.componentStack)
  }

  render() {
    if (this.state.failed) {
      return <div className="scene-error" role="alert"><MonitorOff size={28} /><h2>The 3D view could not start</h2><p>Try a browser with WebGL 2 and hardware acceleration enabled. Your room configuration is preserved.</p><button className="secondary-button" onClick={() => window.location.reload()}>Reload scene</button></div>
    }
    return this.props.children
  }
}
