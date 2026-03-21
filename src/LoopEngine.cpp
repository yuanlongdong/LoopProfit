#include "LoopEngine.h"

#include <QDateTime>
#include <QtMath>

LoopEngine::LoopEngine(DatabaseManager *db, QObject *parent)
    : QObject(parent), m_db(db)
{
}

double LoopEngine::executeBlackBoxProfit(double invested, int aiCount, int attemptNo) const
{
    const double aiFactor = 1.0 + qMin(aiCount, 500) / 1000.0;
    const double attemptDecay = 1.0 - (attemptNo - 1) * 0.08;
    return invested * 0.15 * aiFactor * qMax(0.3, attemptDecay);
}

LoopEngine::ExecutionSummary LoopEngine::runLoop(int userId, double investAmount)
{
    ExecutionSummary summary;
    if (!m_db || investAmount <= 0.0) {
        summary.message = QStringLiteral("投入token必须为正数");
        return summary;
    }

    const auto user = m_db->userById(userId);
    const auto config = m_db->configByUser(userId);

    if (user.userId == 0) {
        summary.message = QStringLiteral("用户不存在");
        return summary;
    }
    if (investAmount > user.walletBalance) {
        summary.message = QStringLiteral("投入token超过钱包余额");
        return summary;
    }

    if (!m_db->beginTransaction()) {
        summary.message = QStringLiteral("无法开启数据库事务");
        return summary;
    }

    const auto now = QDateTime::currentDateTimeUtc();
    const QString tradeId = m_db->recordTokenInvest(userId, investAmount, user.aiCount, now);
    if (tradeId.isEmpty() || !m_db->updateUserAfterRound(userId, -investAmount, 0.0, 0)) {
        m_db->rollback();
        summary.message = QStringLiteral("记录投token失败，已回滚");
        return summary;
    }

    int failedRounds = 0;
    int aiDelta = 0;
    double cumulativeProfit = 0.0;

    for (int round = 1; round <= config.maxRounds; ++round) {
        RoundResult result;
        result.roundNumber = round;
        result.invested = investAmount;

        for (int attempt = 1; attempt <= config.maxAttemptsPerRound; ++attempt) {
            const double p = executeBlackBoxProfit(investAmount, user.aiCount + aiDelta, attempt);
            result.profit += p;
            result.attemptsUsed = attempt;

            const double ratio = (investAmount + result.profit) / investAmount;
            if (ratio >= config.targetMultiplier) {
                result.targetReached = true;
                break;
            }
        }

        summary.rounds.push_back(result);
        cumulativeProfit += result.profit;

        if (!m_db->recordRound(userId, result, now) ||
            !m_db->recordLog(userId,
                             QStringLiteral("ROUND"),
                             QStringLiteral("round=%1 profit=%2 target=%3")
                                 .arg(round)
                                 .arg(result.profit)
                                 .arg(result.targetReached),
                             now)) {
            m_db->rollback();
            summary.message = QStringLiteral("轮次记录失败，已回滚");
            return summary;
        }

        emit roundFinished(userId, round, result.profit, result.targetReached);

        if (result.targetReached) {
            aiDelta += config.aiExpansionStep;
            m_db->recordLog(userId,
                            QStringLiteral("AI_EXPAND"),
                            QStringLiteral("ai +%1 at round %2").arg(config.aiExpansionStep).arg(round),
                            now);
            m_db->recordNotification(userId,
                                     QStringLiteral("TARGET_REACHED"),
                                     QStringLiteral("第%1轮收益达标，已扩AI").arg(round),
                                     now);
        } else {
            failedRounds++;
            if (!config.autoReinvest || failedRounds >= config.stopLossFailures) {
                m_db->recordNotification(userId,
                                         QStringLiteral("STOP_LOSS"),
                                         QStringLiteral("触发止损，循环停止。失败轮次=%1").arg(failedRounds),
                                         now);
                break;
            }
        }
    }

    if (!m_db->updateUserAfterRound(userId, investAmount + cumulativeProfit, cumulativeProfit, aiDelta)) {
        m_db->rollback();
        summary.message = QStringLiteral("用户资产更新失败，已回滚");
        return summary;
    }

    if (!m_db->commit()) {
        m_db->rollback();
        summary.message = QStringLiteral("数据库提交失败");
        return summary;
    }

    summary.success = true;
    summary.tradeId = tradeId;
    summary.aiExpanded = aiDelta;
    summary.cumulativeProfit = cumulativeProfit;
    summary.message = QStringLiteral("循环执行完成");
    return summary;
}
