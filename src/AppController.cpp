#include "AppController.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QtConcurrent>

AppController::AppController(QObject *parent)
    : QObject(parent), m_db(QStringLiteral("loopprofit-app")), m_engine(&m_db)
{
    const QString dbPath = QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("loopprofit.db"));
    if (m_db.open(dbPath) && m_db.initSchema()) {
        m_status = QStringLiteral("数据库已就绪: %1").arg(dbPath);
    } else {
        m_status = QStringLiteral("数据库初始化失败");
    }

    connect(&m_watcher, &QFutureWatcher<LoopEngine::ExecutionSummary>::finished, this, [this]() {
        const auto summary = m_watcher.result();
        if (summary.success) {
            m_status = QStringLiteral("完成。交易ID=%1，收益=%2，扩AI=%3")
                           .arg(summary.tradeId)
                           .arg(summary.cumulativeProfit)
                           .arg(summary.aiExpanded);
        } else {
            m_status = QStringLiteral("失败: %1").arg(summary.message);
        }
        m_running = false;
        emit runningChanged();
        emit statusChanged();
    });
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
    if (m_running) {
        m_status = QStringLiteral("循环执行中，请稍候");
        emit statusChanged();
        return;
    }

    m_running = true;
    emit runningChanged();
    m_status = QStringLiteral("循环任务已提交");
    emit statusChanged();

    m_watcher.setFuture(QtConcurrent::run([this, userId, investAmount]() { return m_engine.runLoop(userId, investAmount); }));
}

QVariantMap AppController::stats(int userId) const
{
    const auto data = m_db.auditStatsByUser(userId);
    return QVariantMap{{QStringLiteral("totalRounds"), data.totalRounds},
                       {QStringLiteral("successRounds"), data.successRounds},
                       {QStringLiteral("failedRounds"), data.failedRounds},
                       {QStringLiteral("totalProfit"), data.totalProfit},
                       {QStringLiteral("successRate"), data.successRate},
                       {QStringLiteral("failureRate"), data.failureRate}};
}

void AppController::refreshStatsStatus(int userId)
{
    const auto data = m_db.auditStatsByUser(userId);
    m_status = QStringLiteral("统计：轮次=%1 成功率=%2% 失败率=%3% 总收益=%4")
                   .arg(data.totalRounds)
                   .arg(data.successRate * 100.0, 0, 'f', 2)
                   .arg(data.failureRate * 100.0, 0, 'f', 2)
                   .arg(data.totalProfit, 0, 'f', 2);
    emit statusChanged();
}

void AppController::discloseConflict(int userId, const QString &conflictType, const QString &details)
{
    ConflictDisclosure disclosure;
    disclosure.userId = userId;
    disclosure.conflictType = conflictType;
    disclosure.details = details;

    const bool ok = m_db.recordConflictDisclosure(disclosure, QDateTime::currentDateTimeUtc());
    m_status = ok ? QStringLiteral("利益冲突已登记") : QStringLiteral("利益冲突登记失败");
    emit statusChanged();
}

void AppController::resolveConflict2(int userId)
{
    const bool ok = m_db.resolveConflict(userId, QStringLiteral("ISSUE_2"), QDateTime::currentDateTimeUtc());
    m_status = ok ? QStringLiteral("利益冲突#2 已标记解决") : QStringLiteral("利益冲突#2 解决失败");
    emit statusChanged();
}
