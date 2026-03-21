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
    if (!m_db) {
        summary.message = QStringLiteral("数据库未初始化");
        return summary;
    }

    const auto user = m_db->userById(userId);
    const auto config = m_db->configByUser(userId);

    if (user.userId == 0) {
        summary.message = QStringLiteral("用户不存在");
        return summary;
    }

    if (m_db->hasOpenConflict(userId, QStringLiteral("ISSUE_2"))) {
        summary.message = QStringLiteral("存在未解决的利益冲突#2，请先处理冲突后再执行循环");
        return summary;
    }

    if (config.maxRounds <= 0 || config.maxAttemptsPerRound <= 0 || config.stopLossFailures <= 0 ||
        config.targetMultiplier <= 1.0 || config.aiExpansionStep < 0) {
        summary.message = QStringLiteral("策略配置非法");
        return summary;
    }

    if (investAmount < 0.0) {
        summary.message = QStringLiteral("投入token必须为正数");
        return summary;
    }

    const double actualInvest = qFuzzyIsNull(investAmount) ? config.investPerRound : investAmount;
    if (actualInvest <= 0.0) {
        summary.message = QStringLiteral("投入token必须为正数");
        return summary;
    }
    if (actualInvest > user.walletBalance) {
        summary.message = QStringLiteral("投入token超过钱包余额");
        return summary;
    }

    if (!m_db->beginTransaction()) {
        summary.message = QStringLiteral("无法开启数据库事务");
        return summary;
    }

    const auto startTs = QDateTime::currentDateTimeUtc();
    const QString tradeId = m_db->recordTokenInvest(userId, actualInvest, user.aiCount, startTs);
    if (tradeId.isEmpty() || !m_db->updateUserAfterRound(userId, -actualInvest, 0.0, 0) ||
        !m_db->recordLog(userId, QStringLiteral("INVEST"), QStringLiteral("trade=%1 amount=%2").arg(tradeId).arg(actualInvest), startTs)) {
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
        result.invested = actualInvest;

        for (int attempt = 1; attempt <= config.maxAttemptsPerRound; ++attempt) {
            const double p = executeBlackBoxProfit(actualInvest, user.aiCount + aiDelta, attempt);
            result.profit += p;
            result.attemptsUsed = attempt;

            const double ratio = (actualInvest + result.profit) / actualInvest;
            if (ratio >= config.targetMultiplier) {
                result.targetReached = true;
                break;
            }
        }

        summary.rounds.push_back(result);
        cumulativeProfit += result.profit;

        const auto roundTs = QDateTime::currentDateTimeUtc();
        if (!m_db->recordRound(userId, result, roundTs) ||
            !m_db->recordLog(userId,
                             QStringLiteral("ROUND"),
                             QStringLiteral("round=%1 profit=%2 target=%3")
                                 .arg(round)
                                 .arg(result.profit)
                                 .arg(result.targetReached),
                             roundTs)) {
            m_db->rollback();
            summary.message = QStringLiteral("轮次记录失败，已回滚");
            return summary;
        }

        emit roundFinished(userId, round, result.profit, result.targetReached);

        if (result.targetReached) {
            aiDelta += config.aiExpansionStep;
            if (!m_db->recordLog(userId,
                                 QStringLiteral("AI_EXPAND"),
                                 QStringLiteral("ai +%1 at round %2").arg(config.aiExpansionStep).arg(round),
                                 roundTs) ||
                !m_db->recordNotification(userId,
                                          QStringLiteral("TARGET_REACHED"),
                                          QStringLiteral("第%1轮收益达标，已扩AI").arg(round),
                                          roundTs)) {
                m_db->rollback();
                summary.message = QStringLiteral("扩AI或通知记录失败，已回滚");
                return summary;
            }
        } else {
            failedRounds++;
            if (!config.autoReinvest || failedRounds >= config.stopLossFailures) {
                if (!m_db->recordNotification(userId,
                                              QStringLiteral("STOP_LOSS"),
                                              QStringLiteral("触发止损，循环停止。失败轮次=%1").arg(failedRounds),
                                              roundTs)) {
                    m_db->rollback();
                    summary.message = QStringLiteral("止损通知记录失败，已回滚");
                    return summary;
                }
                break;
            }
        }
    }

    if (config.sharePoolEnabled &&
        !m_db->recordLog(userId, QStringLiteral("POOL"), QStringLiteral("共享AI池模式已启用"), QDateTime::currentDateTimeUtc())) {
        m_db->rollback();
        summary.message = QStringLiteral("共享池日志记录失败，已回滚");
        return summary;
    }

    if (!m_db->updateUserAfterRound(userId, actualInvest + cumulativeProfit, cumulativeProfit, aiDelta)) {
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
