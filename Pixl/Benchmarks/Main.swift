import Swift

@main
struct PixlBenchmarks {
    static func main() {
        #if os(WASI) && SWIFT_PACKAGE
        fatalError(
            "Invalid performance build: run './.scripts/benchmark wasm' "
                + "to use direct WMO without -num-threads"
        )
        #else
        let report = RepresentativeFrameBenchmark().run()
        if CommandLine.arguments.contains("--json") {
            print(report.json)
        } else {
            print(report.description)
        }
        #endif
    }
}
