import PixlProfiler

nonisolated enum EditorProfileDefinitions {
    static let render = ProfileTrack(1, "CPU")
    static let worker = ProfileTrack(2, "Simulation worker")
    static let gpu = ProfileTrack(3, "GPU")
    static let frame = ProfileScope(0, "Frame", kind: .frame)
    static let simulation = ProfileScope(2, "Simulation", parentScope: 0)
    static let renderFrame = ProfileScope(3, "Render", parentScope: 0)
    static let dispatch = JobProfileDefinitions.dispatch
    static let batch = JobProfileDefinitions.batch
    static let seek = ProfileScope(6, "Seek")
    static let gpuFrame = ProfileScope(7, "GPU frame", kind: .gpuFrame)
    static let preparation = ProfileScope(8, "GPU preparation", parentScope: 7)
    static let diagnostics = ProfileScope(9, "GPU diagnostics", parentScope: 7)
    static let vertex = ProfileScope(10, "GPU vertex", parentScope: 7)
    static let fragment = ProfileScope(11, "GPU fragment", parentScope: 7)
    static let spin = JobProfileDefinitions.spin
    static let mailbox = ProfileScope(13, "Mailbox wait / polling", kind: .wait)
    static let cpuFrameWait = ProfileScope(20, "Frame resource wait", kind: .wait, parentScope: 3)
    static let cpuBuffers = ProfileScope(21, "Prepare / upload buffers", parentScope: 3)
    static let cpuCommandBuffer = ProfileScope(22, "Create command buffer", parentScope: 3)
    static let cpuComputeEncoding = ProfileScope(23, "Encode compute passes", parentScope: 3)
    static let cpuComposition = ProfileScope(24, "Prepare scene composition", parentScope: 3)
    static let cpuDrawableWait = ProfileScope(25, "Drawable wait", kind: .wait, parentScope: 3)
    static let cpuDrawEncoding = ProfileScope(26, "Encode scene draw", parentScope: 3)
    static let cpuSubmission = ProfileScope(27, "Present + submit", parentScope: 3)
    static let gpuRasterClear = ProfileScope(40, "Clear particle raster", parentScope: 7)
    static let gpuRasterCoverage = ProfileScope(41, "Particle coverage", parentScope: 7)
    static let gpuRefinementDispatch = ProfileScope(42, "Prepare refinement dispatch", parentScope: 7)
    static let gpuDepthSeed = ProfileScope(43, "Seed particle depth", parentScope: 7)
    static let gpuDepthHierarchy = ProfileScope(44, "Build depth hierarchy", parentScope: 7)
    static let gpuCompactSurvivors = ProfileScope(45, "Compact unoccluded particles", parentScope: 7)
    static let gpuRefineCoverage = ProfileScope(46, "Refine particle coverage", parentScope: 7)
    static let gpuCullClassify = ProfileScope(47, "Culling classify + local scan", parentScope: 7)
    static let gpuCullScatter = ProfileScope(48, "Culling scatter", parentScope: 7)
    static let gpuCullScan = ProfileScope(49, "Culling parallel scan", parentScope: 7)
    static let gpuCullOffsets = ProfileScope(50, "Culling add offsets", parentScope: 7)
    static let gpuCullFinish = ProfileScope(51, "Culling finish scan", parentScope: 7)
    static let gpuLodPrepare = ProfileScope(52, "LOD prepare", parentScope: 7)
    static let gpuLodClear = ProfileScope(53, "LOD clear tiles", parentScope: 7)
    static let gpuLodCount = ProfileScope(54, "LOD count tiles", parentScope: 7)
    static let gpuLodThresholds = ProfileScope(55, "LOD thresholds", parentScope: 7)
    static let gpuLodClassify = ProfileScope(56, "LOD classify", parentScope: 7)
    static let gpuLodScatter = ProfileScope(57, "LOD scatter", parentScope: 7)
    static let gpuLodScan = ProfileScope(58, "LOD parallel scan", parentScope: 7)
    static let gpuLodOffsets = ProfileScope(59, "LOD add offsets", parentScope: 7)
    static let gpuLodFinish = ProfileScope(60, "LOD finish scan", parentScope: 7)
    static let simScheduling = ProfileScope(70, "Schedule births", parentScope: 81)
    static let simIntegration = ProfileScope(71, "Integration", parentScope: 81)
    static let simRecycling = ProfileScope(72, "Recycle expired particles", parentScope: 81)
    static let simGeneration = ProfileScope(73, "Generate particles", parentScope: 81)
    static let simRetirement = ProfileScope(74, "Retire expired particles", parentScope: 81)
    static let simAllocation = ProfileScope(75, "Allocate new slots", parentScope: 81)
    static let simCommit = ProfileScope(76, "Commit generated particles", parentScope: 81)
    static let simClockScheduling = ProfileScope(80, "Advance simulation clock", parentScope: 2)
    static let simFixedUpdate = ProfileScope(81, "Fixed update", parentScope: 2)
    static let simSampleResult = ProfileScope(82, "Finalize", parentScope: 2)
    // Force every lazy static before starting producer threads.
    static let scopes: [ProfileScope] = [
        frame, simulation, renderFrame, dispatch,
        batch, seek, gpuFrame, preparation,
        diagnostics, vertex, fragment, spin,
        mailbox, simClockScheduling, simFixedUpdate, simSampleResult,
        simScheduling, simIntegration, simRecycling, simGeneration,
        simRetirement, simAllocation, simCommit, JobProfileDefinitions.integrationDispatch,
        JobProfileDefinitions.spawnDispatch, JobProfileDefinitions.integrationBatch, JobProfileDefinitions.spawnBatch, cpuFrameWait,
        cpuBuffers, cpuCommandBuffer, cpuComputeEncoding, cpuComposition,
        cpuDrawableWait, cpuDrawEncoding, cpuSubmission, gpuRasterClear,
        gpuRasterCoverage, gpuRefinementDispatch, gpuDepthSeed, gpuDepthHierarchy,
        gpuCompactSurvivors, gpuRefineCoverage, gpuCullClassify, gpuCullScatter,
        gpuCullScan, gpuCullOffsets, gpuCullFinish, gpuLodPrepare,
        gpuLodClear, gpuLodCount, gpuLodThresholds, gpuLodClassify,
        gpuLodScatter, gpuLodScan, gpuLodOffsets, gpuLodFinish,
    ]
}
