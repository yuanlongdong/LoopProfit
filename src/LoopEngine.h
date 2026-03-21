#pragma once

#include "DatabaseManager.h"

#include <QObject>
#include <QVector>

class LoopEngine : public QObject {
    Q_OBJECT
public:
    explicit LoopEngine(DatabaseManager *db, QObject *parent = nullptr);

    struct ExecutionSummary {
        bool success = false;
        QString message;
        QVector<RoundResult> rounds;
        int aiExpanded = 0;
        double cumulativeProfit = 0.0;
        QString tradeId;
    };

    Q_INVOKABLE ExecutionSummary runLoop(int userId, double investAmount);

signals:
    void roundFinished(int userId, int roundNo, double profit, bool targetReached);

private:
    double executeBlackBoxProfit(double invested, int aiCount, int attemptNo) const;

    DatabaseManager *m_db;
};

Q_DECLARE_METATYPE(LoopEngine::ExecutionSummary)
