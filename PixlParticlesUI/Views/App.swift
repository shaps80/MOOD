import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        #if os(iOS) || os(visionOS)
        DocumentGroupLaunchScene("Pixl Particles") {
            NewDocumentButton(
                "New Particle Effect",
                contentType: .pixlParticles
            )
        }
        #endif

        DocumentGroup { document in
            ContentView(document: document)
                .environment(document)
        } makeDocument: { _, _ in
            ParticleDocument()
        }
        #if os(macOS)
            .defaultSize(width: 1280, height: 720)
            .defaultPosition(.center)
        #endif
    }
}
