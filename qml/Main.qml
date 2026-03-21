import QtQuick
import QtQuick.Controls

ApplicationWindow {
    width: 420
    height: 780
    visible: true
    title: "LoopProfit"

    Column {
        anchors.centerIn: parent
        spacing: 12

        Label {
            width: 360
            wrapMode: Text.Wrap
            text: appController.status
        }

        Button {
            text: "初始化演示数据"
            onClicked: appController.initializeDemoData()
        }

        Button {
            text: "执行循环 (用户1, 投20token)"
            onClicked: appController.startLoop(1, 20)
        }
    }
}
