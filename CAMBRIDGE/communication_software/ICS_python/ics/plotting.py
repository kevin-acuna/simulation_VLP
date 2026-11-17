"""Optional figures; no instrument access."""
import numpy as np

def plot_result(state):
    import matplotlib.pyplot as plt
    capture=state["capture"]; y=np.asarray(capture["YData"]); fs=capture["FsCapture"]
    stride=max(1,len(y)//10000)
    blocks=[y[i:i+stride] for i in range(0,len(y),stride)]
    t=np.arange(len(blocks))*stride/fs
    fig, axes=plt.subplots(2,1,sharex=False,figsize=(10,6))
    axes[0].fill_between(t*1e3,[v.min() for v in blocks],[v.max() for v in blocks],alpha=.65)
    axes[0].set(xlabel="Capture time (ms)",ylabel="Received voltage (V)")
    r=state.get("result",{})
    for tone in r.get("toneResults",[]):
        if tone.get("accepted"):
            a=tone["windowStart_s"]*1e3;b=a+tone["windowDuration_s"]*1e3
            axes[0].axvspan(a,b,color="green",alpha=.15)
    axes[1].plot(np.asarray(r.get("detectorTime_s",[]))*1e3,r.get("detectorTonePurity",[]))
    axes[1].set(xlabel="Capture time (ms)",ylabel="Tone purity",ylim=(-.05,1.05))
    for ax in axes:ax.grid(True)
    fig.tight_layout();plt.show(block=False)
    return fig
