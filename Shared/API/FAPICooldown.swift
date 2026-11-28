import Foundation
import os.log

/// FAPI（znca `f` 值）限流冷却。
///
/// 现场问题：`nxapi` 的 `f` 接口被 Nintendo 按「账号/IP」限流后会返回
/// `429 {"error":"rate_limit","error_description":"Too many attempts to authenticate"}`。
/// 以前 App 只把 429 翻译成「稍后重试」，既不知道要等多久，也会因为用户连点而继续加深限流。
///
/// 这里把服务端给的 `Retry-After` / `X-RateLimit-Reset` 解析成「下次可尝试时间」，
/// 存进 app group prefs，UI 与本地守卫都按它来。
enum FAPICooldown {
    /// 429 没带任何限流头时的保守等待时间（秒）。宁可多等，也不要继续打 Nintendo。
    static let defaultSecondsAfterRateLimit = 600
    /// 5xx 没带限流头时的等待时间。
    static let defaultSecondsAfterServerError = 60
    /// 上限：避免一个坏头把 App 锁死。
    static let maxSeconds = 3600

    static var nowMs: Int { Int(Date().timeIntervalSince1970 * 1000) }
    static var untilMs: Int { AppUserDefaults.shared.fapiCooldownUntil }
    static var provider: String { AppUserDefaults.shared.fapiCooldownProvider }
    static var isActive: Bool { untilMs > nowMs }

    static func remainingSeconds(now: Int = FAPICooldown.nowMs) -> Int {
        max(0, (untilMs - now + 999) / 1000)
    }

    /// 把所有像限流头的响应头抓出来，便于写进诊断快照。
    static func rateLimitHeaders(_ response: HTTPURLResponse?) -> [String: String] {
        guard let response else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let name = key as? String else { continue }
            let lower = name.lowercased()
            if lower.contains("ratelimit") || lower.contains("rate-limit") || lower == "retry-after" {
                result[name] = String(describing: value)
            }
        }
        return result
    }

    /// 从响应里读限流窗口并落到 prefs，返回「可再尝试」的毫秒时间戳。
    @discardableResult
    static func record(from response: HTTPURLResponse?, status: Int, provider: String, fallbackSeconds: Int? = nil) -> Int {
        let headers = rateLimitHeaders(response)
        let seconds = retryAfterSeconds(headers) ?? fallbackSeconds ?? defaultSecondsFor(status)
        record(seconds: seconds, provider: provider, reason: "HTTP \(status)")
        return untilMs
    }

    static func record(seconds: Int, provider: String, reason: String) {
        let clamped = min(max(seconds, 1), maxSeconds)
        let until = nowMs + clamped * 1000
        // 只在把窗口往后推的时候写，避免并发请求互相缩短冷却
        if until > AppUserDefaults.shared.fapiCooldownUntil {
            AppUserDefaults.shared.fapiCooldownUntil = until
        }
        AppUserDefaults.shared.fapiCooldownProvider = provider
        AppUserDefaults.shared.fapiCooldownReason = reason
        os_log(
            "fapiCooldown provider=%{public}@ reason=%{public}@ wait=%{public}ds",
            log: .default,
            type: .error,
            provider, reason, clamped
        )
    }

    static func clear() {
        AppUserDefaults.shared.fapiCooldownUntil = 0
        AppUserDefaults.shared.fapiCooldownProvider = ""
        AppUserDefaults.shared.fapiCooldownReason = ""
    }

    private static func defaultSecondsFor(_ status: Int) -> Int {
        switch status {
        case 429, 503: return defaultSecondsAfterRateLimit
        default: return defaultSecondsAfterServerError
        }
    }

    /// `Retry-After`（秒数或 HTTP 日期）/ `X-RateLimit-Reset`（epoch 秒或剩余秒）解析。
    static func retryAfterSeconds(_ headers: [String: String]) -> Int? {
        for (key, value) in headers {
            let lower = key.lowercased()
            guard lower == "retry-after" || lower.contains("ratelimit-reset") || lower.contains("rate-limit-reset") else {
                continue
            }
            if let seconds = parseRetryValue(value) {
                return seconds
            }
        }
        return nil
    }

    static func parseRetryValue(_ raw: String, now: Date = Date()) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let seconds = Double(trimmed) {
            // epoch 秒（> 10 年）与「剩余秒数」区分开
            if seconds > 1_000_000_000 {
                return Int(seconds - now.timeIntervalSince1970)
            }
            return Int(seconds.rounded(.up))
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: trimmed) {
            return Int(date.timeIntervalSince(now).rounded(.up))
        }
        return nil
    }

    // MARK: - 文案

    static func durationText(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s < 60 { return "\(s) 秒" }
        let minutes = s / 60
        let rest = s % 60
        if rest == 0 { return "\(minutes) 分钟" }
        return "\(minutes) 分 \(rest) 秒"
    }

    static func clockText(_ ms: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(ms) / 1000))
    }

    /// 给 UI 的一句人话，例如：「FAPI 请求被限流，请在 9 分 30 秒后重试（14:52:10 之后）」。
    static func message(prefix: String) -> String {
        guard isActive else { return prefix }
        let remaining = remainingSeconds()
        return "\(prefix)，请在 \(durationText(remaining))后重试（\(clockText(untilMs)) 之后）"
    }
}
