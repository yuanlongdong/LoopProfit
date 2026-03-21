#pragma once

#include "DatabaseManager.h"
#include "LoopEngine.h"

#include <QObject>

class AppController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
public:
    explicit AppController(QObject *parent = nullptr);

    QString status() const { return m_status; }

    Q_INVOKABLE void initializeDemoData();
    Q_INVOKABLE void startLoop(int userId, double investAmount);

signals:
    void statusChanged();

private:
    DatabaseManager m_db;
    LoopEngine m_engine;
    QString m_status;
};
