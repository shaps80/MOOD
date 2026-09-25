import PixlProfiler

nonisolated enum EditorProfileDefinitions {
    static let render = ProfileTrack(1, "Render / simulation")
    static let worker = ProfileTrack(2, "Simulation worker")
    static let gpu = ProfileTrack(3, "GPU")
    static let frame = ProfileScope(0, "Frame", kind: .frame)
    static let simulation = ProfileScope(2, "Simulation (inclusive)")
    static let renderFrame = ProfileScope(3, "Render submission (inclusive)")
    static let dispatch = JobProfileDefinitions.dispatch
    static let batch = JobProfileDefinitions.batch
    static let seek = ProfileScope(6, "Seek")
    static let gpuFrame = ProfileScope(7, "GPU frame", kind: .gpuFrame)
    static let preparation = ProfileScope(8, "GPU preparation")
    static let diagnostics = ProfileScope(9, "GPU diagnostics")
    static let vertex = ProfileScope(10, "GPU vertex")
    static let fragment = ProfileScope(11, "GPU fragment")
    static let spin = JobProfileDefinitions.spin
    static let mailbox = ProfileScope(13, "Mailbox wait / polling", kind: .wait)
    static let cpuFrameWait = ProfileScope(20, "Frame resource wait", kind: .wait)
    static let cpuBuffers = ProfileScope(21, "Prepare / upload buffers")
    static let cpuCommandBuffer = ProfileScope(22, "Create command buffer")
    static let cpuComputeEncoding = ProfileScope(23, "Encode compute passes")
    static let cpuComposition = ProfileScope(24, "Prepare scene composition")
    static let cpuDrawableWait = ProfileScope(25, "Drawable wait", kind: .wait)
    static let cpuDrawEncoding = ProfileScope(26, "Encode scene draw")
    static let cpuSubmission = ProfileScope(27, "Present + submit")
    static let gpuRasterClear = ProfileScope(40, "Clear particle raster")
    static let gpuRasterCoverage = ProfileScope(41, "Particle coverage")
    static let gpuRefinementDispatch = ProfileScope(42, "Prepare refinement dispatch")
    static let gpuDepthSeed = ProfileScope(43, "Seed particle depth")
    static let gpuDepthHierarchy = ProfileScope(44, "Build depth hierarchy")
    static let gpuCompactSurvivors = ProfileScope(45, "Compact unoccluded particles")
    static let gpuRefineCoverage = ProfileScope(46, "Refine particle coverage")
    static let gpuCullClassify = ProfileScope(47, "Culling classify + local scan")
    static let gpuCullScatter = ProfileScope(48, "Culling scatter")
    static let gpuCullScan = ProfileScope(49, "Culling parallel scan")
    static let gpuCullOffsets = ProfileScope(50, "Culling add offsets")
    static let gpuCullFinish = ProfileScope(51, "Culling finish scan")
    static let gpuLodPrepare = ProfileScope(52, "LOD prepare")
    static let gpuLodClear = ProfileScope(53, "LOD clear tiles")
    static let gpuLodCount = ProfileScope(54, "LOD count tiles")
    static let gpuLodThresholds = ProfileScope(55, "LOD thresholds")
    static let gpuLodClassify = ProfileScope(56, "LOD classify")
    static let gpuLodScatter = ProfileScope(57, "LOD scatter")
    static let gpuLodScan = ProfileScope(58, "LOD parallel scan")
    static let gpuLodOffsets = ProfileScope(59, "LOD add offsets")
    static let gpuLodFinish = ProfileScope(60, "LOD finish scan")
    static let simScheduling = ProfileScope(70, "Schedule births")
    static let simIntegration = ProfileScope(71, "Integrate live particles")
    static let simRecycling = ProfileScope(72, "Recycle expired particles")
    static let simGeneration = ProfileScope(73, "Generate particles")
    static let simRetirement = ProfileScope(74, "Retire expired particles")
    static let simAllocation = ProfileScope(75, "Allocate new slots")
    static let simCommit = ProfileScope(76, "Commit generated particles")
    static let simClockScheduling = ProfileScope(80, "Advance simulation clock")
    static let simFixedUpdate = ProfileScope(81, "Fixed update (inclusive)")
    static let simSampleResult = ProfileScope(82, "Finalize sample + diagnostics")
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
