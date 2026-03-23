package com.loopprofit.android

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.loopprofit.android.databinding.ActivityMainBinding
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.runButton.setOnClickListener {
            binding.resultView.text = runLoop().format()
        }
    }

    private fun runLoop(): Summary {
        val wallet = binding.walletInput.text?.toString()?.toDoubleOrNull() ?: 0.0
        val invest = binding.investInput.text?.toString()?.toDoubleOrNull() ?: 0.0
        val aiCount = binding.aiCountInput.text?.toString()?.toIntOrNull() ?: 99
        val maxRounds = binding.maxRoundsInput.text?.toString()?.toIntOrNull() ?: 12
        val maxAttempts = binding.maxAttemptsInput.text?.toString()?.toIntOrNull() ?: 4
        val targetMultiplier = binding.targetMultiplierInput.text?.toString()?.toDoubleOrNull() ?: 2.0
        val stopLoss = binding.stopLossInput.text?.toString()?.toIntOrNull() ?: 3
        val aiExpandStep = binding.aiExpandStepInput.text?.toString()?.toIntOrNull() ?: 2
        val autoReinvest = binding.autoReinvestInput.isChecked

        if (invest <= 0.0) return Summary(error = "投入金额必须大于 0")
        if (wallet < invest) return Summary(error = "投入金额不能超过钱包余额")

        var aiDelta = 0
        var failedRounds = 0
        var cumulativeProfit = 0.0
        val rounds = mutableListOf<Round>()

        for (round in 1..maxRounds) {
            var roundProfit = 0.0
            var attemptsUsed = 0
            var reached = false
            for (attempt in 1..maxAttempts) {
                val profit = executeBlackBoxProfit(invest, aiCount + aiDelta, attempt)
                roundProfit += profit
                attemptsUsed = attempt
                val ratio = (invest + roundProfit) / invest
                if (ratio >= targetMultiplier) {
                    reached = true
                    break
                }
            }
            cumulativeProfit += roundProfit
            rounds += Round(round, roundProfit, attemptsUsed, reached, aiCount + aiDelta)

            if (reached) {
                aiDelta += aiExpandStep
            } else {
                failedRounds += 1
                if (!autoReinvest || failedRounds >= stopLoss) break
            }
        }

        return Summary(
            cumulativeProfit = cumulativeProfit,
            aiExpanded = aiDelta,
            finalBalance = wallet - invest + invest + cumulativeProfit,
            rounds = rounds
        )
    }

    private fun executeBlackBoxProfit(invested: Double, aiCount: Int, attemptNo: Int): Double {
        val aiFactor = 1.0 + min(aiCount, 500) / 1000.0
        val attemptDecay = 1.0 - (attemptNo - 1) * 0.08
        return invested * 0.15 * aiFactor * max(0.3, attemptDecay.toDouble())
    }
}

data class Round(
    val roundNumber: Int,
    val profit: Double,
    val attemptsUsed: Int,
    val reached: Boolean,
    val aiCount: Int,
)

data class Summary(
    val cumulativeProfit: Double = 0.0,
    val aiExpanded: Int = 0,
    val finalBalance: Double = 0.0,
    val rounds: List<Round> = emptyList(),
    val error: String? = null,
) {
    fun format(): String {
        error?.let { return "失败：$it" }
        val header = buildString {
            appendLine(String.format(Locale.US, "累计收益：%.2f", cumulativeProfit))
            appendLine("扩 AI 数量：$aiExpanded")
            appendLine(String.format(Locale.US, "最终余额：%.2f", finalBalance))
            appendLine("--- 轮次详情 ---")
        }
        val details = rounds.joinToString(separator = "\n") {
            String.format(
                Locale.US,
                "第 %d 轮 | AI=%d | profit=%.2f | attempts=%d | %s",
                it.roundNumber,
                it.aiCount,
                it.profit,
                it.attemptsUsed,
                if (it.reached) "达标" else "未达标",
            )
        }
        return header + details
    }
}
