import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "polidog.headlint"
  ipcTarget: "polidog.headlint"
  manageIpc: false

  // Base handler plus `analyze <url>` for keybindings / scripts.
  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function analyze(url: string): void { urlField.text = url; root.open(); root.analyze(url) }
  }

  property var result: null
  property string error: ""
  property string target: ""
  // Images are fetched with curl into here; Qt's own HTTP/2 client fails on some servers.
  property string imageDir: ""

  readonly property var card: result ? Model.preview(result) : null
  readonly property var icons: result ? Model.favicons(result) : []
  readonly property var imageUrls: Model.uniq([card ? card.image : ""].concat(icons.map(function(i) { return i.url })))

  function localImage(url) {
    var i = imageUrls.indexOf(url)
    return url && i >= 0 && imageDir && !imageProc.running ? "file://" + imageDir + "/" + i : ""
  }
  readonly property var tally: result ? Model.counts(result) : null
  readonly property color dim: Qt.darker(root.bar.foreground, 1.4)

  function analyze(raw) {
    var url = Model.normalizeUrl(raw)
    if (!url || runProc.running) return
    root.target = url
    root.error = ""
    runProc.running = true
  }

  function levelColor(level) {
    if (level === "ng") return root.bar.urgent
    if (level === "warn") return Color.accent
    if (level === "info") return root.dim
    return root.bar.foreground
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) Qt.callLater(function() { urlField.forceActiveFocus(); urlField.selectAll() })

  Process {
    id: runProc
    // The shell's PATH usually lacks ~/.cargo/bin, where `cargo install` puts headlint.
    command: ["sh", "-c", "PATH=\"$HOME/.cargo/bin:$HOME/.local/bin:$PATH\" exec headlint --json \"$1\"", "sh", root.target]
    stdout: StdioCollector { id: out; waitForEnd: true }
    stderr: StdioCollector { id: err; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) {
        root.result = null
        root.error = String(err.text || "").replace(/^fetching .*\n?/m, "").trim() || ("headlint exited with " + code)
        return
      }
      try {
        root.result = Model.parse(String(out.text || ""))
        root.imageDir = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-headlint/" + Date.now()
        imageProc.running = true
      } catch (e) {
        root.result = null
        root.error = "headlint の出力を読めませんでした: " + e
      }
    }
  }

  Process {
    id: imageProc
    command: ["sh", "-c", "rm -rf \"${1%/*}\"; mkdir -p \"$1\" && cd \"$1\" || exit 1; shift; i=0; for u; do curl -fsL --max-time 15 -o \"$i\" \"$u\" & i=$((i+1)); done; wait", "sh", root.imageDir].concat(root.imageUrls)
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰜏" + (runProc.running ? " …" : "")
    tooltipText: root.error || (root.result ? root.target : "headlint")
    active: root.tally !== null && root.tally.ng > 0
    onPressed: function(b) {
      if (b === Qt.RightButton && root.target) root.analyze(root.target)
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: urlField
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(760))

    ScrollView {
      id: scrollArea
      anchors.fill: parent
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

      Column {
        id: panelColumn
        width: scrollArea.availableWidth
        spacing: Style.space(10)

        Text {
          text: "headlint"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        TextField {
          id: urlField
          width: parent.width
          enabled: !runProc.running
          placeholderText: "https://example.com"
          foreground: root.bar.foreground
          font.family: root.bar.fontFamily
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.analyze(urlField.text); event.accepted = true }
          }
        }

        Text {
          visible: runProc.running || root.error !== "" || !root.result
          width: parent.width
          wrapMode: Text.WordWrap
          text: runProc.running ? root.target + " を解析中…"
              : root.error !== "" ? root.error
              : "URL を入れて Enter"
          color: root.error !== "" ? root.bar.urgent : root.dim
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }

        Text {
          visible: root.tally !== null && !runProc.running
          text: root.tally ? "✓ " + root.tally.ok + "   ! " + root.tally.warn + "   ✗ " + root.tally.ng : ""
          color: root.tally && root.tally.ng > 0 ? root.bar.urgent : root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        // --- SNS card preview (rendered og:image / twitter:image) -------------
        Rectangle {
          id: cardBox
          visible: root.card !== null
          width: parent.width
          height: cardCol.implicitHeight
          radius: Style.cornerRadius
          color: "transparent"
          border.color: Qt.darker(root.bar.foreground, 2.5)
          border.width: 1
          clip: true

          Column {
            id: cardCol
            width: parent.width

            Item {
              width: parent.width
              // 1.91:1 like X / Facebook large cards.
              height: root.card && root.card.image ? Math.round(width / 1.91) : 0
              visible: height > 0

              Image {
                id: ogImage
                anchors.fill: parent
                source: root.card ? root.localImage(root.card.image) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
              }
              Text {
                anchors.centerIn: parent
                visible: ogImage.status !== Image.Ready
                text: ogImage.status === Image.Error ? "画像を読み込めませんでした" : "読み込み中…"
                color: ogImage.status === Image.Error ? root.bar.urgent : root.dim
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Column {
              width: parent.width
              padding: Style.space(10)
              spacing: Style.space(4)

              Text {
                width: parent.width - parent.padding * 2
                text: root.card ? (root.card.host || root.card.siteName) : ""
                color: root.dim
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
              Text {
                width: parent.width - parent.padding * 2
                text: root.card ? (root.card.title || "(title なし)") : ""
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }
              Text {
                width: parent.width - parent.padding * 2
                visible: text !== ""
                text: root.card ? root.card.description : ""
                color: root.dim
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.card && root.card.url) { Qt.openUrlExternally(root.card.url); root.close() }
          }
        }

        // --- Favicons, rendered at their real size (capped) -------------------
        Flow {
          visible: root.icons.length > 0
          width: parent.width
          spacing: Style.space(12)

          Repeater {
            model: root.icons
            delegate: Column {
              id: iconCell
              required property var modelData
              spacing: Style.space(2)

              Item {
                width: Style.space(64)
                height: Style.space(64)
                Image {
                  id: iconImg
                  anchors.centerIn: parent
                  source: root.localImage(iconCell.modelData.url)
                  asynchronous: true
                  cache: false
                  fillMode: Image.PreserveAspectFit
                  width: Math.min(parent.width, implicitWidth)
                  height: Math.min(parent.height, implicitHeight)
                }
                Text {
                  anchors.centerIn: parent
                  visible: iconImg.status === Image.Error
                  text: "✗"
                  color: root.bar.urgent
                  font.pixelSize: Style.font.title
                }
              }
              Text {
                width: Style.space(64)
                horizontalAlignment: Text.AlignHCenter
                text: iconCell.modelData.label + (iconImg.status === Image.Ready ? "\n" + iconImg.implicitWidth + "×" + iconImg.implicitHeight : "")
                color: root.dim
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
              }
            }
          }
        }

        // --- headlint sections ------------------------------------------------
        Repeater {
          model: root.result ? root.result.sections : []

          delegate: Column {
            id: section
            required property var modelData
            width: panelColumn.width
            spacing: Style.space(4)

            PanelSeparator { foreground: root.bar.foreground }

            Text {
              text: section.modelData.name
              color: root.dim
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }

            Repeater {
              model: section.modelData.items
              delegate: Row {
                id: line
                required property var modelData
                width: section.width
                spacing: Style.space(8)

                Text {
                  id: markText
                  text: Model.mark(line.modelData.level)
                  width: Style.space(12)
                  color: root.levelColor(line.modelData.level)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  id: labelText
                  text: line.modelData.label
                  width: Style.space(130)
                  elide: Text.ElideRight
                  color: root.levelColor(line.modelData.level)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                }
                Text {
                  width: line.width - markText.width - labelText.width - line.spacing * 2
                  text: line.modelData.value
                  wrapMode: Text.WrapAnywhere
                  // robots.txt raw body is long; keep it readable but bounded.
                  maximumLineCount: 12
                  elide: Text.ElideRight
                  color: line.modelData.level === "info" ? root.dim : root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          text: "Enter 解析 · Esc 閉じる · カードでページを開く · 右クリックで再解析"
          color: Qt.darker(root.bar.foreground, 1.6)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
