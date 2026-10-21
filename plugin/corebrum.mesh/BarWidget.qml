import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Corebrum mesh status. Lit when zenohd (7447), the daemon, and the web UI
// (6502) are all up; dimmed when stopped. Left toggles the mesh: it starts
// it when nothing is up and stops it otherwise. Right opens the Corebrum menu.
BarWidget {
  id: root
  moduleName: "corebrum.mesh"

  readonly property string upCmd: Quickshell.env("HOME") + "/.local/bin/corebrum-up"
  readonly property int refreshSec: Number(setting("refreshIntervalSec", 5))

  property bool zenoh: false
  property bool daemon: false
  property bool web: false
  readonly property int upCount: (zenoh ? 1 : 0) + (daemon ? 1 : 0) + (web ? 1 : 0)
  readonly property bool running: upCount === 3

  function refresh() {
    if (!probe.running) probe.running = true
  }

  function soon() { settle.restart() }

  function statusText() {
    function mark(ok) { return ok ? "up" : "down" }
    var head = running ? "Corebrum running" : (upCount === 0 ? "Corebrum stopped" : "Corebrum degraded")
    return head + "\nzenoh " + mark(zenoh) + " · daemon " + mark(daemon) + " · web " + mark(web)
      + "\nLeft: " + (upCount === 0 ? "start" : "stop") + " · Right: menu"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "corebrum.mesh"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Process {
    id: probe
    command: ["bash", "-c",
      "z=0 d=0 w=0; " +
      "ss -ltnH 'sport = :7447' | grep -q . && z=1; " +
      "pgrep -u \"$USER\" -f '[c]orebrum daemon' >/dev/null && d=1; " +
      "ss -ltnH 'sport = :6502' | grep -q . && w=1; " +
      "echo $z $d $w"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parts = String(text || "").trim().split(" ")
        root.zenoh = parts[0] === "1"
        root.daemon = parts[1] === "1"
        root.web = parts[2] === "1"
      }
    }
  }

  Timer {
    interval: Math.max(2, root.refreshSec) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Startup takes a few seconds; re-probe shortly after an action.
  Timer {
    id: settle
    interval: 3000
    repeat: false
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰧑"
    slotSize: Style.bar.statusSlot
    active: root.running
    opacity: root.upCount === 0 ? 0.45 : 1
    tooltipText: root.statusText()
    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.bar.run("omarchy menu toggle corebrum")
      // A clean stop first so a session left with dead panes is rebuilt
      // instead of reattached.
      else if (root.upCount === 0) root.bar.run(root.upCmd + " stop >/dev/null; " + root.upCmd)
      else root.bar.run(root.upCmd + " stop | xargs -0 notify-send -a Corebrum")
      root.soon()
    }
  }
}
