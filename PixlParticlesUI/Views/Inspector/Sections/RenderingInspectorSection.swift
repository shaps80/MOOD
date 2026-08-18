import PixlRenderer
import SwiftUI

struct RenderingInspectorSection: View {
    @Binding var mode: ParticleRenderer.Mode
    @Binding var sizeSpace: BillboardRenderer.SizeSpace
    @Binding var facing: BillboardRenderer.Facing
    @Binding var width: Double
    @Binding var height: Double
    @Binding var rotation: Double

    var body: some View {
        Section("Rendering") {
            LabeledContent("Mode") {
                Picker("Mode", selection: $mode) {
                    ForEach(ParticleRenderer.Mode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(.primary)
            }

            if mode == .billboard {
                LabeledContent("Facing") {
                    Picker("Facing", selection: $facing) {
                        ForEach(BillboardRenderer.Facing.allCases, id: \.self) { facing in
                            Text(facing.title).tag(facing)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
                LabeledContent("Size Space") {
                    Picker("Size Space", selection: $sizeSpace) {
                        ForEach(BillboardRenderer.SizeSpace.allCases, id: \.self) { space in
                            Text(space.title).tag(space)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
                LabeledContent("Width") {
                    Field(
                        value: $width,
                        step: 0.25,
                        range: 0 ... 10_000,
                        fractionDigits: 2
                    )
                }
                LabeledContent("Height") {
                    Field(
                        value: $height,
                        step: 0.25,
                        range: 0 ... 10_000,
                        fractionDigits: 2
                    )
                }
                LabeledContent("Rotation") {
                    Field(
                        value: $rotation,
                        step: 1,
                        displayScale: 180 / .pi,
                        fractionDigits: 1
                    )
                }
            }
        }
    }
}

private extension ParticleRenderer.Mode {
    var title: LocalizedStringResource {
        switch self {
        case .point: "Point"
        case .billboard: "Billboard"
        }
    }
}

private extension BillboardRenderer.SizeSpace {
    var title: LocalizedStringResource {
        switch self {
        case .world: "World"
        case .screen: "Screen"
        }
    }
}

private extension BillboardRenderer.Facing {
    var title: LocalizedStringResource {
        switch self {
        case .camera: "Camera"
        case .cameraPlane: "Camera Plane"
        case .cameraPosition: "Camera Position"
        }
    }
}
