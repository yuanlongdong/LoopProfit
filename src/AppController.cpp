#include "AppController.h"

#include <QCoreApplication>
#include <QDir>

AppController::AppController(QObject *parent)
    : QObject(parent), m_db(QStringLiteral("loopprofit-app")), m_engine(&m_db)
{
    const QString dbPath = QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("loopprofit.db"));
    if (m_db.open(dbPath) && m_db.initSchema()) {
        m_status = QStringLiteral("数据库已就绪: %1").arg(dbPath);
    } else {
        m_status = QStringLiteral("数据库初始化失败");
    }
}

void AppController::initializeDemoData()
{
    UserProfile user;
    user.userId = 1;
    user.username = QStringLiteral("demo_user");
    user.walletBalance = 500.0;
    user.aiCount = 99;
    user.totalProfit = 0.0;

    StrategyConfig cfg;
    cfg.userId = 1;
    cfg.targetMultiplier = 2.0;
    cfg.investPerRound = 20.0;
    cfg.maxRounds = 12;
    cfg.maxAttemptsPerRound = 4;
    cfg.stopLossFailures = 3;
    cfg.aiExpansionStep = 2;
    cfg.autoReinvest = true;

    if (m_db.upsertUser(user) && m_db.upsertConfig(cfg)) {
        m_status = QStringLiteral("已初始化演示账户");
    } else {
        m_status = QStringLiteral("初始化演示账户失败");
    }
    emit statusChanged();
}

void AppController::startLoop(int userId, double investAmount)
{
    const auto summary = m_engine.runLoop(userId, investAmount);
    if (summary.success) {
        m_status = QStringLiteral("完成。交易ID=%1，收益=%2，扩AI=%3")
                       .arg(summary.tradeId)
                       .arg(summary.cumulativeProfit)
                       .arg(summary.aiExpanded);
    } else {
        m_status = QStringLiteral("失败: %1").arg(summary.message);
    }
    emit statusChanged();
}
