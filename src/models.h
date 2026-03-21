#pragma once

#include <QString>

struct UserProfile {
    int userId = 0;
    QString username;
    double walletBalance = 0.0;
    int aiCount = 99;
    double totalProfit = 0.0;
};

struct StrategyConfig {
    int userId = 0;
    double targetMultiplier = 2.0;
    double investPerRound = 1.0;
    int maxRounds = 10;
    int maxAttemptsPerRound = 3;
    int stopLossFailures = 3;
    int aiExpansionStep = 1;
    bool autoReinvest = true;
    bool sharePoolEnabled = false;
};

struct RoundResult {
    int roundNumber = 0;
    double invested = 0.0;
    double profit = 0.0;
    bool targetReached = false;
    int attemptsUsed = 0;
};
