#include "DatabaseManager.h"
#include "LoopEngine.h"

#include <QSqlQuery>
#include <QtTest>

class LoopEngineTest : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void investValidation();
    void transactionAndRecords();
    void auditStats();

private:
    DatabaseManager *m_db = nullptr;
    LoopEngine *m_engine = nullptr;
};

void LoopEngineTest::initTestCase()
{
    m_db = new DatabaseManager(QStringLiteral("loopprofit-test"));
    QVERIFY(m_db->open(QStringLiteral(":memory:")));
    QVERIFY(m_db->initSchema());

    UserProfile user{1, QStringLiteral("u1"), 100.0, 99, 0.0};
    StrategyConfig cfg;
    cfg.userId = 1;
    cfg.targetMultiplier = 1.2;
    cfg.investPerRound = 10.0;
    cfg.maxRounds = 3;
    cfg.maxAttemptsPerRound = 2;
    cfg.stopLossFailures = 2;
    cfg.aiExpansionStep = 1;
    cfg.autoReinvest = true;

    QVERIFY(m_db->upsertUser(user));
    QVERIFY(m_db->upsertConfig(cfg));

    m_engine = new LoopEngine(m_db);
}

void LoopEngineTest::investValidation()
{
    auto s = m_engine->runLoop(1, -10.0);
    QVERIFY(!s.success);

    s = m_engine->runLoop(1, 1000.0);
    QVERIFY(!s.success);
}

void LoopEngineTest::transactionAndRecords()
{
    const auto s = m_engine->runLoop(1, 10.0);
    QVERIFY(s.success);
    QVERIFY(!s.tradeId.isEmpty());

    QSqlQuery q(m_db->database());
    QVERIFY(q.exec(QStringLiteral("SELECT COUNT(1) FROM token_invest WHERE user_id = 1")));
    QVERIFY(q.next());
    QVERIFY(q.value(0).toInt() >= 1);

    QVERIFY(q.exec(QStringLiteral("SELECT wallet_balance,total_profit FROM users WHERE id = 1")));
    QVERIFY(q.next());
    QVERIFY(q.value(0).toDouble() > 90.0);
    QVERIFY(q.value(1).toDouble() >= 0.0);
}

void LoopEngineTest::auditStats()
{
    const auto stats = m_db->auditStatsByUser(1);
    QVERIFY(stats.totalRounds > 0);
    QVERIFY(stats.successRounds + stats.failedRounds == stats.totalRounds);
    QVERIFY(stats.successRate >= 0.0);
    QVERIFY(stats.failureRate >= 0.0);
}

QTEST_MAIN(LoopEngineTest)
#include "test_loopengine.moc"
