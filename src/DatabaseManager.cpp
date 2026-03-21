#include "DatabaseManager.h"

#include <QSqlQuery>
#include <QUuid>

DatabaseManager::DatabaseManager(const QString &connectionName)
    : m_connectionName(connectionName)
{
}

DatabaseManager::~DatabaseManager()
{
    if (m_db.isValid() && m_db.isOpen()) {
        m_db.close();
    }
    if (QSqlDatabase::contains(m_connectionName)) {
        QSqlDatabase::removeDatabase(m_connectionName);
    }
}

bool DatabaseManager::open(const QString &dbPath)
{
    if (QSqlDatabase::contains(m_connectionName)) {
        m_db = QSqlDatabase::database(m_connectionName);
    } else {
        m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connectionName);
    }
    m_db.setDatabaseName(dbPath);
    if (!m_db.open()) {
        return false;
    }

    QSqlQuery pragma(m_db);
    return pragma.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
    return m_db.open();
}

bool DatabaseManager::initSchema()
{
    const QStringList ddl = {
        QStringLiteral("CREATE TABLE IF NOT EXISTS users ("
                       "id INTEGER PRIMARY KEY,"
                       "username TEXT NOT NULL UNIQUE,"
                       "wallet_balance REAL NOT NULL,"
                       "ai_count INTEGER NOT NULL,"
                       "total_profit REAL NOT NULL"
                       ")"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS config ("
                       "user_id INTEGER PRIMARY KEY,"
                       "target_multiplier REAL NOT NULL,"
                       "invest_per_round REAL NOT NULL,"
                       "max_rounds INTEGER NOT NULL,"
                       "max_attempts_per_round INTEGER NOT NULL,"
                       "stop_loss_failures INTEGER NOT NULL,"
                       "ai_expansion_step INTEGER NOT NULL,"
                       "auto_reinvest INTEGER NOT NULL,"
                       "share_pool_enabled INTEGER NOT NULL,"
                       "FOREIGN KEY(user_id) REFERENCES users(id)"
                       ")"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS token_invest ("
                       "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                       "user_id INTEGER NOT NULL,"
                       "trade_id TEXT NOT NULL UNIQUE,"
                       "amount REAL NOT NULL,"
                       "ai_count INTEGER NOT NULL,"
                       "created_at TEXT NOT NULL,"
                       "FOREIGN KEY(user_id) REFERENCES users(id)"
                       ")"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS rounds ("
                       "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                       "user_id INTEGER NOT NULL,"
                       "round_no INTEGER NOT NULL,"
                       "invested REAL NOT NULL,"
                       "profit REAL NOT NULL,"
                       "target_reached INTEGER NOT NULL,"
                       "attempts_used INTEGER NOT NULL,"
                       "created_at TEXT NOT NULL,"
                       "FOREIGN KEY(user_id) REFERENCES users(id)"
                       ")"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS logs ("
                       "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                       "user_id INTEGER NOT NULL,"
                       "event_type TEXT NOT NULL,"
                       "message TEXT NOT NULL,"
                       "created_at TEXT NOT NULL"
                       ")"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS notifications ("
                       "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                       "user_id INTEGER NOT NULL,"
                       "kind TEXT NOT NULL,"
                       "content TEXT NOT NULL,"
                       "created_at TEXT NOT NULL"
                       ")"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS conflict_disclosures ("
                       "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                       "user_id INTEGER NOT NULL,"
                       "conflict_type TEXT NOT NULL,"
                       "details TEXT NOT NULL,"
                       "resolved INTEGER NOT NULL DEFAULT 0,"
                       "created_at TEXT NOT NULL,"
                       "resolved_at TEXT,"
                       "FOREIGN KEY(user_id) REFERENCES users(id)"
                       ")")};

    for (const auto &sql : ddl) {
        QSqlQuery q(m_db);
        if (!q.exec(sql)) {
            return false;
        }
    }
    return true;
}

bool DatabaseManager::upsertUser(const UserProfile &profile)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO users(id, username, wallet_balance, ai_count, total_profit) "
                             "VALUES(?, ?, ?, ?, ?) "
                             "ON CONFLICT(id) DO UPDATE SET "
                             "username=excluded.username,"
                             "wallet_balance=excluded.wallet_balance,"
                             "ai_count=excluded.ai_count,"
                             "total_profit=excluded.total_profit"));
    q.addBindValue(profile.userId);
    q.addBindValue(profile.username);
    q.addBindValue(profile.walletBalance);
    q.addBindValue(profile.aiCount);
    q.addBindValue(profile.totalProfit);
    return q.exec();
}

bool DatabaseManager::upsertConfig(const StrategyConfig &config)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO config(user_id, target_multiplier, invest_per_round, max_rounds, "
                             "max_attempts_per_round, stop_loss_failures, ai_expansion_step, auto_reinvest, share_pool_enabled) "
                             "VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?) "
                             "ON CONFLICT(user_id) DO UPDATE SET "
                             "target_multiplier=excluded.target_multiplier,"
                             "invest_per_round=excluded.invest_per_round,"
                             "max_rounds=excluded.max_rounds,"
                             "max_attempts_per_round=excluded.max_attempts_per_round,"
                             "stop_loss_failures=excluded.stop_loss_failures,"
                             "ai_expansion_step=excluded.ai_expansion_step,"
                             "auto_reinvest=excluded.auto_reinvest,"
                             "share_pool_enabled=excluded.share_pool_enabled"));
    q.addBindValue(config.userId);
    q.addBindValue(config.targetMultiplier);
    q.addBindValue(config.investPerRound);
    q.addBindValue(config.maxRounds);
    q.addBindValue(config.maxAttemptsPerRound);
    q.addBindValue(config.stopLossFailures);
    q.addBindValue(config.aiExpansionStep);
    q.addBindValue(config.autoReinvest ? 1 : 0);
    q.addBindValue(config.sharePoolEnabled ? 1 : 0);
    return q.exec();
}

UserProfile DatabaseManager::userById(int userId) const
{
    UserProfile profile;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT id, username, wallet_balance, ai_count, total_profit FROM users WHERE id=?"));
    q.addBindValue(userId);
    if (q.exec() && q.next()) {
        profile.userId = q.value(0).toInt();
        profile.username = q.value(1).toString();
        profile.walletBalance = q.value(2).toDouble();
        profile.aiCount = q.value(3).toInt();
        profile.totalProfit = q.value(4).toDouble();
    }
    return profile;
}

StrategyConfig DatabaseManager::configByUser(int userId) const
{
    StrategyConfig config;
    config.userId = userId;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT target_multiplier, invest_per_round, max_rounds, max_attempts_per_round, "
                             "stop_loss_failures, ai_expansion_step, auto_reinvest, share_pool_enabled "
                             "FROM config WHERE user_id=?"));
    q.addBindValue(userId);
    if (q.exec() && q.next()) {
        config.targetMultiplier = q.value(0).toDouble();
        config.investPerRound = q.value(1).toDouble();
        config.maxRounds = q.value(2).toInt();
        config.maxAttemptsPerRound = q.value(3).toInt();
        config.stopLossFailures = q.value(4).toInt();
        config.aiExpansionStep = q.value(5).toInt();
        config.autoReinvest = q.value(6).toInt() == 1;
        config.sharePoolEnabled = q.value(7).toInt() == 1;
    }
    return config;
}

AuditStats DatabaseManager::auditStatsByUser(int userId) const
{
    AuditStats stats;

    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT COUNT(1), "
                             "COALESCE(SUM(CASE WHEN target_reached = 1 THEN 1 ELSE 0 END), 0), "
                             "COALESCE(SUM(CASE WHEN target_reached = 0 THEN 1 ELSE 0 END), 0), "
                             "COALESCE(SUM(profit), 0.0) "
                             "FROM rounds WHERE user_id = ?"));
    q.addBindValue(userId);
    if (q.exec() && q.next()) {
        stats.totalRounds = q.value(0).toInt();
        stats.successRounds = q.value(1).toInt();
        stats.failedRounds = q.value(2).toInt();
        stats.totalProfit = q.value(3).toDouble();

        if (stats.totalRounds > 0) {
            stats.successRate = static_cast<double>(stats.successRounds) / static_cast<double>(stats.totalRounds);
            stats.failureRate = static_cast<double>(stats.failedRounds) / static_cast<double>(stats.totalRounds);
        }
    }
    return stats;
}


QVector<RoundReportRow> DatabaseManager::roundReportByUser(int userId, const QString &fromIso, const QString &toIso) const
{
    QVector<RoundReportRow> rows;
    QSqlQuery q(m_db);

    if (fromIso.isEmpty() && toIso.isEmpty()) {
        q.prepare(QStringLiteral("SELECT round_no, invested, profit, target_reached, created_at FROM rounds WHERE user_id = ? ORDER BY round_no ASC"));
        q.addBindValue(userId);
    } else {
        q.prepare(QStringLiteral("SELECT round_no, invested, profit, target_reached, created_at FROM rounds "
                                 "WHERE user_id = ? AND created_at BETWEEN ? AND ? ORDER BY round_no ASC"));
        q.addBindValue(userId);
        q.addBindValue(fromIso);
        q.addBindValue(toIso);
    }

    if (!q.exec()) {
        return rows;
    }

    while (q.next()) {
        RoundReportRow row;
        row.roundNumber = q.value(0).toInt();
        row.invested = q.value(1).toDouble();
        row.profit = q.value(2).toDouble();
        row.targetReached = q.value(3).toInt() == 1;
        row.createdAt = q.value(4).toString();
        rows.push_back(row);
    }
    return rows;
}

bool DatabaseManager::beginTransaction() { return m_db.transaction(); }
bool DatabaseManager::commit() { return m_db.commit(); }
bool DatabaseManager::rollback() { return m_db.rollback(); }

QString DatabaseManager::recordTokenInvest(int userId, double amount, int aiCount, const QDateTime &ts)
{
    for (int i = 0; i < 3; ++i) {
        const QString tradeId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral("INSERT INTO token_invest(user_id, trade_id, amount, ai_count, created_at) VALUES(?, ?, ?, ?, ?)"));
        q.addBindValue(userId);
        q.addBindValue(tradeId);
        q.addBindValue(amount);
        q.addBindValue(aiCount);
        q.addBindValue(ts.toString(Qt::ISODate));
        if (q.exec()) {
            return tradeId;
        }
    }
    return {};
    const QString tradeId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO token_invest(user_id, trade_id, amount, ai_count, created_at) VALUES(?, ?, ?, ?, ?)"));
    q.addBindValue(userId);
    q.addBindValue(tradeId);
    q.addBindValue(amount);
    q.addBindValue(aiCount);
    q.addBindValue(ts.toString(Qt::ISODate));
    if (!q.exec()) {
        return {};
    }
    return tradeId;
}

bool DatabaseManager::recordRound(int userId, const RoundResult &result, const QDateTime &ts)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO rounds(user_id, round_no, invested, profit, target_reached, attempts_used, created_at) "
                             "VALUES(?, ?, ?, ?, ?, ?, ?)"));
    q.addBindValue(userId);
    q.addBindValue(result.roundNumber);
    q.addBindValue(result.invested);
    q.addBindValue(result.profit);
    q.addBindValue(result.targetReached ? 1 : 0);
    q.addBindValue(result.attemptsUsed);
    q.addBindValue(ts.toString(Qt::ISODate));
    return q.exec();
}

bool DatabaseManager::recordLog(int userId, const QString &eventType, const QString &message, const QDateTime &ts)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO logs(user_id, event_type, message, created_at) VALUES(?, ?, ?, ?)"));
    q.addBindValue(userId);
    q.addBindValue(eventType);
    q.addBindValue(message);
    q.addBindValue(ts.toString(Qt::ISODate));
    return q.exec();
}

bool DatabaseManager::recordNotification(int userId, const QString &kind, const QString &content, const QDateTime &ts)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO notifications(user_id, kind, content, created_at) VALUES(?, ?, ?, ?)"));
    q.addBindValue(userId);
    q.addBindValue(kind);
    q.addBindValue(content);
    q.addBindValue(ts.toString(Qt::ISODate));
    return q.exec();
}


bool DatabaseManager::recordConflictDisclosure(const ConflictDisclosure &disclosure, const QDateTime &ts)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO conflict_disclosures(user_id, conflict_type, details, created_at) VALUES(?, ?, ?, ?)"));
    q.addBindValue(disclosure.userId);
    q.addBindValue(disclosure.conflictType);
    q.addBindValue(disclosure.details);
    q.addBindValue(ts.toString(Qt::ISODate));
    return q.exec();
}


bool DatabaseManager::resolveConflict(int userId, const QString &conflictType, const QDateTime &ts)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("UPDATE conflict_disclosures SET resolved = 1, resolved_at = ? WHERE user_id = ? AND conflict_type = ? AND resolved = 0"));
    q.addBindValue(ts.toString(Qt::ISODate));
    q.addBindValue(userId);
    q.addBindValue(conflictType);
    return q.exec();
}

bool DatabaseManager::hasOpenConflict(int userId, const QString &conflictType) const
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("SELECT COUNT(1) FROM conflict_disclosures WHERE user_id = ? AND conflict_type = ? AND resolved = 0"));
    q.addBindValue(userId);
    q.addBindValue(conflictType);
    if (q.exec() && q.next()) {
        return q.value(0).toInt() > 0;
    }
    return false;
}

bool DatabaseManager::updateUserAfterRound(int userId, double walletDelta, double profitDelta, int aiDelta)
{
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("UPDATE users "
                             "SET wallet_balance = wallet_balance + ?, "
                             "total_profit = total_profit + ?, "
                             "ai_count = ai_count + ? "
                             "WHERE id = ?"));
    q.addBindValue(walletDelta);
    q.addBindValue(profitDelta);
    q.addBindValue(aiDelta);
    q.addBindValue(userId);
    return q.exec();
}
