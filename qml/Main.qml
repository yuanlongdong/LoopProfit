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

        Label {
            text: appController.running ? "状态：运行中" : "状态：空闲"
        }

        Button {
            text: "初始化演示数据"
            enabled: !appController.running
            onClicked: appController.initializeDemoData()
        }

        Button {
            text: "执行循环 (用户1, 投20token)"
            enabled: !appController.running
            onClicked: appController.startLoop(1, 20)
        }

        Button {
            text: "查看统计"
            onClicked: appController.refreshStatsStatus(1)
        }

        Button {
            text: "登记利益冲突#2"
            onClicked: appController.discloseConflict(1, "ISSUE_2", "共享AI池收益分配潜在冲突，已上报审计")
        }

        Button {
            text: "解决利益冲突#2"
            onClicked: appController.resolveConflict2(1)
        }

        Button {
            text: "导出轮次报表CSV"
            onClicked: appController.exportRoundReportCsv(1, "./round_report_user1.csv")
        }
    }
}
