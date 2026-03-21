#pragma once

#include "models.h"

#include <QDateTime>
#include <QSqlDatabase>
#include <QString>
#include <QVector>

class DatabaseManager {
public:
    explicit DatabaseManager(const QString &connectionName = QStringLiteral("loopprofit"));
    ~DatabaseManager();

    bool open(const QString &dbPath);
    bool initSchema();

    bool upsertUser(const UserProfile &profile);
    bool upsertConfig(const StrategyConfig &config);

    UserProfile userById(int userId) const;
    StrategyConfig configByUser(int userId) const;
    AuditStats auditStatsByUser(int userId) const;
    QVector<RoundReportRow> roundReportByUser(int userId, const QString &fromIso, const QString &toIso) const;

    bool beginTransaction();
    bool commit();
    bool rollback();

    QString recordTokenInvest(int userId, double amount, int aiCount, const QDateTime &ts);
    bool recordRound(int userId, const RoundResult &result, const QDateTime &ts);
    bool recordLog(int userId, const QString &eventType, const QString &message, const QDateTime &ts);
    bool recordNotification(int userId, const QString &kind, const QString &content, const QDateTime &ts);
    bool recordConflictDisclosure(const ConflictDisclosure &disclosure, const QDateTime &ts);
    bool resolveConflict(int userId, const QString &conflictType, const QDateTime &ts);
    bool hasOpenConflict(int userId, const QString &conflictType) const;

    bool updateUserAfterRound(int userId, double walletDelta, double profitDelta, int aiDelta);

    QSqlDatabase database() const { return m_db; }

private:
    QSqlDatabase m_db;
    QString m_connectionName;
};
