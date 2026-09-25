import PixlProfiler

nonisolated enum EditorProfileDefinitions {
    static let render = ProfileTrack(1, "Render / simulation")
    static let worker = ProfileTrack(2, "Simulation worker")
    static let gpu = ProfileTrack(3, "GPU")
    static let frame = ProfileScope(0, "Frame", kind: .frame)
    static let simulation = ProfileScope(2, "Simulation sample")
    static let renderFrame = ProfileScope(3, "Encode + drawable / frame waits")
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
    // Force every lazy static before starting producer threads.
    static let scopes: [ProfileScope] = [frame, simulation, renderFrame, dispatch,
                                         batch, seek, gpuFrame, preparation, diagnostics, vertex, fragment, spin, mailbox]
}
