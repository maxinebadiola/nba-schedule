import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "../code/schedule.js" as Schedule

PlasmaExtras.Representation {
    id: fullRoot

    property var    gamesGroups:  []
    property int    gamesCount:   0
    property bool   loading:      false
    property string errorMessage: ""
    property string lastUpdated:  ""
    signal refreshRequested()

    Layout.minimumWidth:    Kirigami.Units.gridUnit * 22
    Layout.minimumHeight:   Kirigami.Units.gridUnit * 20
    Layout.preferredWidth:  Kirigami.Units.gridUnit * 28
    Layout.preferredHeight: Kirigami.Units.gridUnit * 40

    function dayGroupLabel(dateStr, fallback) {
        var todayStr = Qt.formatDate(new Date(), "yyyy-MM-dd");
        var tom = new Date();
        tom.setDate(tom.getDate() + 1);
        var tomorrowStr = Qt.formatDate(tom, "yyyy-MM-dd");
        if (dateStr === todayStr)    return "Today";
        if (dateStr === tomorrowStr) return "Tomorrow";
        return fallback;
    }

    header: PlasmaExtras.PlasmoidHeading {
        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.Heading {
                Layout.fillWidth: true
                level: 3
                text: Plasmoid.configuration.teamName || "NBA Schedule"
                elide: Text.ElideRight
            }

            PlasmaComponents.Label {
                visible: fullRoot.lastUpdated !== ""
                text: "Updated " + fullRoot.lastUpdated
                opacity: 0.5
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                enabled: !fullRoot.loading
                onClicked: fullRoot.refreshRequested()
                PlasmaComponents.ToolTip.text: "Refresh"
                PlasmaComponents.ToolTip.visible: hovered
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }
    }

    Item {
        anchors.fill: parent

        //spinner, only before first load
        PlasmaComponents.BusyIndicator {
            anchors.centerIn: parent
            visible: fullRoot.loading && fullRoot.gamesCount === 0
            running: visible
        }

        PlasmaExtras.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.largeSpacing * 4
            visible: !fullRoot.loading &&
                     (fullRoot.errorMessage !== "" || fullRoot.gamesCount === 0)
            iconName: fullRoot.errorMessage !== "" ? "dialog-warning" : "calendar-symbolic"
            text: fullRoot.errorMessage !== ""
                  ? fullRoot.errorMessage
                  : "No games in the selected date range"
        }

        Flickable {
            id: flick
            anchors.fill: parent
            visible: fullRoot.gamesCount > 0
            contentWidth:  width
            contentHeight: contentCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

            Column {
                id: contentCol
                width: flick.width
                spacing: 0

                Repeater {
                    model: fullRoot.gamesGroups

                    Column {
                        width: contentCol.width
                        spacing: 0

                        //date header
                        Rectangle {
                            width:  parent.width
                            height: dateLabel.implicitHeight + Kirigami.Units.smallSpacing * 3
                            color:  Kirigami.Theme.alternateBackgroundColor

                            PlasmaComponents.Label {
                                id: dateLabel
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: Kirigami.Units.largeSpacing
                                }
                                text: "── " + fullRoot.dayGroupLabel(modelData.date, modelData.label) + " ──"
                                font.bold: true
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                color: Kirigami.Theme.textColor
                            }
                        }

                        Repeater {
                            model: modelData.games

                            Column {
                                id: gameContainer
                                width: parent.width
                                spacing: 0

                                property bool expanded: false

                                Item {
                                    id: gameRow
                                    width:  parent.width
                                    height: rowContent.implicitHeight + Kirigami.Units.smallSpacing * 2

                                    Rectangle {
                                        anchors.fill: parent
                                        color:   Kirigami.Theme.highlightColor
                                        opacity: rowMouse.containsMouse ? 0.08 : 0
                                        Behavior on opacity { NumberAnimation { duration: 80 } }
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: gameContainer.expanded = !gameContainer.expanded
                                    }

                                    RowLayout {
                                        id: rowContent
                                        anchors {
                                            left:  parent.left
                                            right: parent.right
                                            verticalCenter: parent.verticalCenter
                                            leftMargin:  Kirigami.Units.largeSpacing
                                            rightMargin: Kirigami.Units.largeSpacing
                                        }
                                        spacing: Kirigami.Units.smallSpacing

                                        //time / status
                                        Item {
                                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                                            implicitHeight: statusLabel.implicitHeight

                                            //live dot
                                            Rectangle {
                                                id: liveDot
                                                visible: modelData.statusType === "live"
                                                anchors {
                                                    right: statusLabel.left
                                                    rightMargin: 4
                                                    verticalCenter: parent.verticalCenter
                                                }
                                                width: 7; height: 7; radius: 4
                                                color: Kirigami.Theme.positiveTextColor

                                                SequentialAnimation on opacity {
                                                    running: liveDot.visible
                                                    loops:   Animation.Infinite
                                                    NumberAnimation { to: 0.15; duration: 700 }
                                                    NumberAnimation { to: 1.0;  duration: 700 }
                                                }
                                            }

                                            PlasmaComponents.Label {
                                                id: statusLabel
                                                anchors {
                                                    left: parent.left
                                                    verticalCenter: parent.verticalCenter
                                                }
                                                text: {
                                                    if (modelData.statusType === "upcoming") {
                                                        return modelData.datetime
                                                            ? Qt.formatTime(
                                                                new Date(modelData.datetime),
                                                                Qt.locale().timeFormat(Locale.ShortFormat))
                                                            : "TBD";
                                                    }
                                                    return modelData.statusLabel;
                                                }
                                                font.bold:      modelData.statusType === "live"
                                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                                color: {
                                                    if (modelData.statusType === "live")
                                                        return Kirigami.Theme.positiveTextColor;
                                                    if (modelData.statusType === "final")
                                                        return Kirigami.Theme.disabledTextColor;
                                                    return Kirigami.Theme.textColor;
                                                }
                                            }
                                        }

                                        //matchup
                                        PlasmaComponents.Label {
                                            Layout.fillWidth: true
                                            text: modelData.visitorAbbr + "  @  " + modelData.homeAbbr
                                                  + (modelData.postseason ? "  ·  PO" : "")
                                            font.bold: modelData.statusType === "live"
                                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        //score badge
                                        Item {
                                            Layout.preferredWidth: Kirigami.Units.gridUnit * 4.5
                                            implicitHeight: scoreBadge.implicitHeight

                                            Rectangle {
                                                id: scoreBadge
                                                visible: modelData.statusType !== "upcoming"
                                                anchors.centerIn: parent
                                                width:  scoreText.implicitWidth  + Kirigami.Units.smallSpacing * 2
                                                height: scoreText.implicitHeight + 4
                                                radius: 4
                                                color: modelData.statusType === "live"
                                                       ? Qt.rgba(Kirigami.Theme.positiveTextColor.r,
                                                                 Kirigami.Theme.positiveTextColor.g,
                                                                 Kirigami.Theme.positiveTextColor.b, 0.15)
                                                       : Qt.rgba(Kirigami.Theme.disabledTextColor.r,
                                                                 Kirigami.Theme.disabledTextColor.g,
                                                                 Kirigami.Theme.disabledTextColor.b, 0.10)

                                                PlasmaComponents.Label {
                                                    id: scoreText
                                                    anchors.centerIn: parent
                                                    text: {
                                                        var v = modelData.visitorScore;
                                                        var h = modelData.homeScore;
                                                        return v + " – " + h;
                                                    }
                                                    font.bold: modelData.statusType === "live"
                                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                                                    color: modelData.statusType === "live"
                                                           ? Kirigami.Theme.positiveTextColor
                                                           : Kirigami.Theme.textColor
                                                }
                                            }
                                        }

                                        Kirigami.Icon {
                                            source: gameContainer.expanded ? "arrow-up" : "arrow-down"
                                            Layout.preferredWidth:  Kirigami.Units.iconSizes.small
                                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                            opacity: 0.4
                                        }
                                    }

                                    Rectangle {
                                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                        height: 1
                                        color: Kirigami.Theme.textColor
                                        opacity: 0.12
                                    }
                                }

                                Item {
                                    id: expandPanel
                                    width:  parent.width
                                    height: gameContainer.expanded
                                            ? expandInner.implicitHeight + Kirigami.Units.smallSpacing * 3
                                            : 0
                                    clip: true
                                    visible: height > 0

                                    Behavior on height {
                                        NumberAnimation { duration: 140; easing.type: Easing.InOutQuad }
                                    }

                                    Column {
                                        id: expandInner
                                        width: parent.width - Kirigami.Units.largeSpacing * 4
                                        anchors {
                                            top:              parent.top
                                            topMargin:        Kirigami.Units.smallSpacing
                                            horizontalCenter: parent.horizontalCenter
                                        }
                                        spacing: Kirigami.Units.smallSpacing

                                        //full names
                                        RowLayout {
                                            width: parent.width
                                            PlasmaComponents.Label {
                                                Layout.fillWidth: true
                                                text: modelData.visitorFullName
                                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                opacity: 0.75
                                            }
                                            PlasmaComponents.Label {
                                                text: "@"
                                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                opacity: 0.45
                                            }
                                            PlasmaComponents.Label {
                                                Layout.fillWidth: true
                                                text: modelData.homeFullName
                                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                opacity: 0.75
                                                horizontalAlignment: Text.AlignRight
                                            }
                                        }

                                        //quarter scores
                                        Column {
                                            width: parent.width
                                            visible: modelData.statusType !== "upcoming"
                                            spacing: 2

                                            //period headers
                                            RowLayout {
                                                width: parent.width
                                                Item { Layout.preferredWidth: Kirigami.Units.gridUnit * 3 }
                                                Repeater {
                                                    model: Math.max(modelData.period, 4)
                                                    PlasmaComponents.Label {
                                                        Layout.fillWidth: true
                                                        text: index < 4
                                                              ? "Q" + (index + 1)
                                                              : (index === 4 ? "OT" : "OT" + (index - 3))
                                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                        opacity: 0.55
                                                        horizontalAlignment: Text.AlignHCenter
                                                    }
                                                }
                                                PlasmaComponents.Label {
                                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                                    text: "Total"
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                    font.bold: true
                                                    opacity: 0.7
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }

                                            //visitor
                                            RowLayout {
                                                width: parent.width
                                                PlasmaComponents.Label {
                                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                                    text: modelData.visitorAbbr
                                                    font.bold: true
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                }
                                                Repeater {
                                                    model: Math.max(modelData.period, 4)
                                                    PlasmaComponents.Label {
                                                        Layout.fillWidth: true
                                                        text: "–"
                                                        opacity: 0.35
                                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                        horizontalAlignment: Text.AlignHCenter
                                                    }
                                                }
                                                PlasmaComponents.Label {
                                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                                    text: modelData.visitorScore >= 0 ? modelData.visitorScore : "–"
                                                    font.bold: true
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }

                                            //home
                                            RowLayout {
                                                width: parent.width
                                                PlasmaComponents.Label {
                                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                                    text: modelData.homeAbbr
                                                    font.bold: true
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                }
                                                Repeater {
                                                    model: Math.max(modelData.period, 4)
                                                    PlasmaComponents.Label {
                                                        Layout.fillWidth: true
                                                        text: "–"
                                                        opacity: 0.35
                                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                        horizontalAlignment: Text.AlignHCenter
                                                    }
                                                }
                                                PlasmaComponents.Label {
                                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                                    text: modelData.homeScore >= 0 ? modelData.homeScore : "–"
                                                    font.bold: true
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                    horizontalAlignment: Text.AlignRight
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                        height: 1
                                        color: Kirigami.Theme.textColor
                                        opacity: 0.12
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        //refresh bar
        Rectangle {
            id: refreshBar
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 2
            visible: fullRoot.loading && fullRoot.gamesCount > 0
            color: Kirigami.Theme.highlightColor

            SequentialAnimation on opacity {
                running: refreshBar.visible
                loops:   Animation.Infinite
                NumberAnimation { to: 0.15; duration: 700 }
                NumberAnimation { to: 0.8;  duration: 700 }
            }
        }
    }
}
