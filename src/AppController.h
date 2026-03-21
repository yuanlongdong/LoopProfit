#pragma once

#include "DatabaseManager.h"
#include "LoopEngine.h"

#include <QFutureWatcher>
#include <QVariantMap>
#include <QObject>

class AppController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
public:
    explicit AppController(QObject *parent = nullptr);

    QString status() const { return m_status; }
    bool running() const { return m_running; }

    Q_INVOKABLE void initializeDemoData();
    Q_INVOKABLE void startLoop(int userId, double investAmount);
    Q_INVOKABLE QVariantMap stats(int userId) const;
    Q_INVOKABLE void refreshStatsStatus(int userId);
    Q_INVOKABLE void discloseConflict(int userId, const QString &conflictType, const QString &details);

signals:
    void statusChanged();
    void runningChanged();

private:
    DatabaseManager m_db;
    LoopEngine m_engine;
    QFutureWatcher<LoopEngine::ExecutionSummary> m_watcher;
    QString m_status;
    bool m_running = false;
};
