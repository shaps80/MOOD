#if os(WASI)
import JavaScriptKit
import PixlBackendTestSupport
import Swift

@main
struct PixlBackendBrowserTestRunner {
    static func main() {
        let runtime = BrowserBenchmarkRuntime()
        BrowserBenchmarkRuntime.retained = runtime
        runtime.start()
    }
}

private final class BrowserBenchmarkRuntime {
    // The browser owns the event loop, so retain the runtime for the page lifetime.
    nonisolated(unsafe) static var retained: BrowserBenchmarkRuntime?

    private var initialDelay: JSClosure?
    private var warmupDelay: JSClosure?
    private var measurementDelay: JSClosure?

    func start() {
        setStatus("Waiting 1 second before warm-up…")
        initialDelay = JSClosure { [weak self] _ in
            self?.beginWarmup()
            return .undefined
        }
        schedule(initialDelay!, after: 1_000)
    }

    private func beginWarmup() {
        setStatus("Warming up ResourcePool (results discarded)…")
        warmupDelay = JSClosure { [weak self] _ in
            self?.runWarmup()
            return .undefined
        }
        schedule(warmupDelay!, after: 50)
    }

    private func runWarmup() {
        do {
            try ResourcePoolSuite.runChecks()
            _ = ResourcePoolSuite.runBenchmarks()
        } catch {
            finishFailure(error)
            return
        }

        setStatus("Running measured suite…")
        measurementDelay = JSClosure { [weak self] _ in
            self?.runMeasuredSuite()
            return .undefined
        }
        schedule(measurementDelay!, after: 50)
    }

    private func runMeasuredSuite() {
        do {
            try ResourcePoolSuite.runChecks()
            let report = ResourcePoolSuite.runBenchmarks()
            finish(report)
        } catch {
            finishFailure(error)
        }
    }

    private func finish(_ report: ResourcePoolBenchmarkReport) {
        let text = reportText(report)
        setStatus("Complete")
        setResults(text)

        let global = JSObject.global
        global.pixlBackendTestReport = .string(text)
        global.pixlBackendTestComplete = .boolean(true)
    }

    private func finishFailure(_ error: Error) {
        let text = "ResourcePool browser suite failed:\n\(error)"
        setStatus("Failed")
        setResults(text)

        let global = JSObject.global
        global.pixlBackendTestReport = .string(text)
        global.pixlBackendTestComplete = .boolean(false)
        _ = global.console.error(text)
    }

    private func schedule(_ callback: JSClosure, after milliseconds: Int) {
        _ = JSObject.global.setTimeout!(callback, milliseconds)
    }

    private func setStatus(_ text: String) {
        element(id: "status")?.textContent = .string(text)
    }

    private func setResults(_ text: String) {
        element(id: "results")?.textContent = .string(text)
    }

    private func element(id: String) -> JSObject? {
        JSObject.global.document.getElementById(id).object
    }

    private func reportText(_ report: ResourcePoolBenchmarkReport) -> String {
        var text = "ResourcePool — \(ResourcePoolSuite.elementCount) resources\n"
        text += "Browser: \(JSObject.global.navigator.userAgent.string ?? "Unknown")\n"
        text += "Configuration: release\n"
        text += "Warm-up: 1 second idle + one discarded suite\n\n"
        text += benchmarkText(report.coldStart)
        text += benchmarkText(report.sequentialLookup)
        text += benchmarkText(report.randomLookup)
        text += benchmarkText(report.update)
        text += benchmarkText(report.churn)
        let checksum = report.coldStart.checksum
            &+ report.sequentialLookup.checksum
            &+ report.randomLookup.checksum
            &+ report.update.checksum
            &+ report.churn.checksum
        text += "Checksum: \(checksum)"
        return text
    }

    private func benchmarkText(_ result: BenchmarkResult) -> String {
        let perOperation = result.nanosecondsPerOperationHundredths
        return "\(result.name)\n"
            + "  Average: \(milliseconds(result.averageNanoseconds)) ms\n"
            + "  Per operation: \(decimalHundredths(perOperation)) ns\n"
            + "  Min: \(milliseconds(result.minimumNanoseconds)) ms\n"
            + "  Max: \(milliseconds(result.maximumNanoseconds)) ms\n"
            + "  Iterations: \(result.iterations)\n"
    }

    private func milliseconds(_ nanoseconds: UInt64) -> String {
        decimalThousandths(nanoseconds / 1_000)
    }

    private func decimalThousandths(_ thousandths: UInt64) -> String {
        let whole = thousandths / 1_000
        let fraction = thousandths % 1_000
        return "\(whole).\(leftPadded(fraction, width: 3))"
    }

    private func decimalHundredths(_ hundredths: UInt64) -> String {
        let whole = hundredths / 100
        let fraction = hundredths % 100
        return "\(whole).\(leftPadded(fraction, width: 2))"
    }

    private func leftPadded(_ value: UInt64, width: Int) -> String {
        let text = String(value)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }
}
#else
import Swift

@main
struct PixlBackendBrowserTestRunner {
    static func main() {
        print("PixlBackendBrowserTestRunner must run in a browser WASM build.")
    }
}
#endif
