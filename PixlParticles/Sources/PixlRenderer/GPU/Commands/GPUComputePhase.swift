import Swift

/// Stable operation identifiers; labels are resolved by diagnostics consumers.
public enum GPUComputePhase: UInt32, Sendable {
    case preparation, diagnostics
    case rasterClear
    case rasterCoverage
    case refinementDispatch
    case depthSeed
    case depthHierarchy
    case compactSurvivors
    case refineCoverage
    case cullClassify
    case cullScatter
    case cullScan
    case cullOffsets
    case cullFinish
    case lodPrepare
    case lodClear
    case lodCount
    case lodThresholds
    case lodClassify
    case lodScatter
    case lodScan
    case lodOffsets
    case lodFinish

    public var isDiagnostics: Bool { self == .diagnostics }
}
