import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: compactRoot

    implicitWidth: Kirigami.Units.iconSizes.medium * 2
    implicitHeight: Kirigami.Units.iconSizes.medium * 2

    readonly property bool isVertical: Plasmoid.formFactor === Plasmoid.Vertical

    MouseArea {
        anchors.fill: parent
        onClicked: Plasmoid.activated()
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        Kirigami.Icon {
            visible: Plasmoid.configuration.teamId <= 0
            Layout.alignment: Qt.AlignHCenter
            source: "games-highscores"
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
        }

        PlasmaComponents.Label {
            visible: Plasmoid.configuration.teamId > 0
            Layout.alignment: Qt.AlignHCenter
            text: Plasmoid.configuration.teamName.split(" ").pop() // last word e.g. "Lakers"
            font.bold: true
            font.pixelSize: Kirigami.Units.smallSpacing * 3
            minimumPixelSize: 6
            fontSizeMode: Text.Fit
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
