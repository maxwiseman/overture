import OvertureRockets
import Observation
import RealityKit
import SwiftUI
import UIKit

struct RocketModelView: View {
    let vehicle: String

    @State private var didLoad = false
    @State private var loadFailed = false

    static func supports(vehicle: String) -> Bool {
        RocketModelAsset(vehicle: vehicle) != nil
    }

    static func prewarmCommonModel() async {
        try? await RocketEntityCache.shared.preload(sceneName: RocketModelAsset.falcon9.sceneName)
    }

    var body: some View {
        if let asset = RocketModelAsset(vehicle: vehicle) {
            ZStack {
                fallbackArtwork(isLoading: !loadFailed)
                    .opacity(didLoad ? 0 : 1)

                RealityView { content in
                    do {
                        let entity = try await RocketEntityCache.shared.clone(
                            sceneName: asset.sceneName
                        )
                        content.add(entity)
                        content.add(rocketDirectionalLight(
                            position: SIMD3<Float>(3, 4, 5),
                            intensity: 3_000
                        ))
                        content.add(rocketDirectionalLight(
                            position: SIMD3<Float>(-3, 1, 2),
                            intensity: 800
                        ))
                        content.camera = .virtual
                        content.cameraTarget = entity
                        didLoad = true
                    } catch {
                        loadFailed = true
                    }
                } placeholder: {
                    Color.clear
                }
                .realityViewLayoutBehavior(.centered)
                .realityViewCameraControls(.orbit)
                .opacity(didLoad ? 1 : 0)
            }
            .accessibilityLabel("Interactive 3D model of \(vehicle)")
            .accessibilityHint("Drag to orbit around the rocket")
        } else {
            fallbackArtwork(isLoading: false)
        }
    }

    private func fallbackArtwork(isLoading: Bool) -> some View {
        ZStack {
            RocketArtwork(vehicle: vehicle)

            if isLoading {
                ProgressView()
                    .tint(.white)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }
}

struct RocketCardModelView: View {
    let vehicle: String

    @State private var snapshotStore = RocketCardSnapshotStore.shared
    @State private var ownsRenderer = false

    var body: some View {
        if let asset = RocketModelAsset(vehicle: vehicle) {
            if let snapshot = snapshotStore.snapshots[asset.sceneName] {
                Image(uiImage: snapshot)
                    .resizable()
                    .scaledToFit()
                    .accessibilityHidden(true)
            } else {
                ZStack {
                    if ownsRenderer {
                        RocketPerspectiveView(
                            sceneName: asset.sceneName,
                            onSnapshot: { image in
                                snapshotStore.complete(image, for: asset.sceneName)
                                ownsRenderer = false
                            },
                            onFailure: {
                                snapshotStore.cancelRendering(asset.sceneName)
                                ownsRenderer = false
                            }
                        )
                    }

                    RocketArtwork(vehicle: vehicle)
                }
                .onAppear {
                    ownsRenderer = snapshotStore.claimRenderer(for: asset.sceneName)
                }
                .onDisappear {
                    if ownsRenderer {
                        snapshotStore.cancelRendering(asset.sceneName)
                    }
                }
                .accessibilityHidden(true)
            }
        } else {
            RocketArtwork(vehicle: vehicle)
                .accessibilityHidden(true)
        }
    }
}

struct RocketDetailModelView: View {
    let vehicle: String
    let isCentered: Bool

    var body: some View {
        if let asset = RocketModelAsset(vehicle: vehicle) {
            RocketLivePerspectiveView(
                sceneName: asset.sceneName,
                isCentered: isCentered
            )
                .accessibilityLabel("3D model of \(vehicle)")
                .accessibilityHint("Drag to rotate and pinch to zoom")
        } else {
            RocketArtwork(vehicle: vehicle)
        }
    }
}

private struct RocketLivePerspectiveView: UIViewRepresentable {
    let sceneName: String
    let isCentered: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let view = makeRocketARView()
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "rocket-detail-model"
        view.accessibilityLabel = "Interactive 3D rocket model"
        view.accessibilityHint = "Drag to rotate and pinch to zoom"
        view.isMultipleTouchEnabled = true
        context.coordinator.installGestures(on: view)
        context.coordinator.loadTask = Task { @MainActor [weak view] in
            guard let view else { return }
            guard let cameraRig = try? await installRocketScene(
                named: sceneName,
                visibleHeightFraction: 0.72,
                in: view
            ) else { return }
            context.coordinator.cameraRig = cameraRig
            context.coordinator.applyFraming(to: view, isCentered: isCentered)
        }
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.applyFraming(to: uiView, isCentered: isCentered)
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.loadTask?.cancel()
        coordinator.removeGestures(from: uiView)
        uiView.scene.anchors.removeAll()
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var loadTask: Task<Void, Never>?
        var cameraRig: RocketCameraRig?
        private var appliedCenteredState: Bool?
        private var installedGestures: [UIGestureRecognizer] = []
        private var panStartOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        private var zoomScale: Float = 1
        private var pinchStartScale: Float = 1

        func installGestures(on view: ARView) {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            panGesture.maximumNumberOfTouches = 1
            panGesture.delegate = self

            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinchGesture.delegate = self

            installedGestures = [panGesture, pinchGesture]
            installedGestures.forEach(view.addGestureRecognizer)
        }

        func removeGestures(from view: ARView) {
            installedGestures.forEach(view.removeGestureRecognizer)
            installedGestures.removeAll()
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let modelPivot = cameraRig?.modelPivot,
                  let view = gesture.view else { return }

            switch gesture.state {
            case .began:
                panStartOrientation = modelPivot.orientation
            case .changed:
                let translation = gesture.translation(in: view)
                let yaw = simd_quatf(
                    angle: -Float(translation.x) * 0.008,
                    axis: SIMD3<Float>(0, 1, 0)
                )
                let pitch = simd_quatf(
                    angle: -Float(translation.y) * 0.006,
                    axis: SIMD3<Float>(1, 0, 0)
                )
                modelPivot.orientation = yaw * panStartOrientation * pitch
            default:
                break
            }
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let modelPivot = cameraRig?.modelPivot else { return }

            switch gesture.state {
            case .began:
                pinchStartScale = zoomScale
            case .changed:
                zoomScale = min(max(pinchStartScale * Float(gesture.scale), 0.55), 2.4)
                modelPivot.scale = SIMD3<Float>(repeating: zoomScale)
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func applyFraming(to view: ARView, isCentered: Bool) {
            guard appliedCenteredState != isCentered, let cameraRig else { return }
            let shouldAnimate = appliedCenteredState != nil
            appliedCenteredState = isCentered
            frameDetailRocket(
                cameraRig,
                in: view,
                isCentered: isCentered,
                animated: shouldAnimate
            )
        }
    }
}

private struct RocketPerspectiveView: UIViewRepresentable {
    let sceneName: String
    let onSnapshot: @MainActor (UIImage) -> Void
    let onFailure: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let view = makeRocketARView()

        context.coordinator.loadTask = Task { @MainActor [weak view] in
            guard let view else { return }

            do {
                _ = try await installRocketScene(
                    named: sceneName,
                    visibleHeightFraction: 0.46,
                    in: view
                )

                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                view.snapshot(saveToHDR: false) { image in
                    Task { @MainActor in
                        if let image {
                            onSnapshot(image)
                        } else {
                            onFailure()
                        }
                    }
                }
            } catch {
                onFailure()
            }
        }

        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.loadTask?.cancel()
        uiView.scene.anchors.removeAll()
    }

    final class Coordinator {
        var loadTask: Task<Void, Never>?
    }
}

@MainActor
private func makeRocketARView() -> ARView {
    let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    view.environment.background = .color(.clear)
    view.renderOptions = [
        .disableCameraGrain,
        .disableDepthOfField,
        .disableGroundingShadows,
        .disableHDR,
        .disableMotionBlur,
    ]
    return view
}

@MainActor
private func installRocketScene(
    named sceneName: String,
    visibleHeightFraction: Float,
    in view: ARView
) async throws -> RocketCameraRig {
    let entity = try await RocketEntityCache.shared.clone(sceneName: sceneName)
    try Task.checkCancellation()

    let bounds = entity.visualBounds(relativeTo: nil)
    let visibleHeight = bounds.extents.y * visibleHeightFraction
    let target = SIMD3<Float>(
        bounds.center.x,
        bounds.max.y - visibleHeight / 2,
        bounds.center.z
    )
    let verticalFieldOfView: Float = 32
    let cameraDistance = visibleHeight / (2 * tan(verticalFieldOfView * .pi / 360))

    let camera = PerspectiveCamera()
    camera.camera = PerspectiveCameraComponent(
        near: 0.001,
        far: max(bounds.extents.y * 4, 10),
        fieldOfViewInDegrees: verticalFieldOfView,
        fieldOfViewOrientation: .vertical
    )
    camera.look(
        at: target,
        from: SIMD3<Float>(bounds.center.x, target.y, bounds.max.z + cameraDistance),
        upVector: SIMD3<Float>(0, 1, 0),
        relativeTo: nil
    )

    let anchor = AnchorEntity(world: .zero)
    anchor.addChild(entity)

    let modelPivot = Entity()
    modelPivot.position = bounds.center
    anchor.addChild(modelPivot)
    entity.setParent(modelPivot, preservingWorldTransform: true)

    anchor.addChild(camera)
    anchor.addChild(rocketDirectionalLight(
        position: SIMD3<Float>(3, 4, 5),
        intensity: 3_000
    ))
    anchor.addChild(rocketDirectionalLight(
        position: SIMD3<Float>(-3, 1, 2),
        intensity: 800
    ))
    view.scene.addAnchor(anchor)

    return RocketCameraRig(
        camera: camera,
        modelPivot: modelPivot,
        center: bounds.center,
        maximumY: bounds.max.y,
        maximumZ: bounds.max.z,
        height: bounds.extents.y
    )
}

private struct RocketCameraRig {
    let camera: PerspectiveCamera
    let modelPivot: Entity
    let center: SIMD3<Float>
    let maximumY: Float
    let maximumZ: Float
    let height: Float
}

@MainActor
private func frameDetailRocket(
    _ cameraRig: RocketCameraRig,
    in view: ARView,
    isCentered: Bool,
    animated: Bool
) {
    let visibleHeightFraction: Float = isCentered ? 1.35 : 0.88
    let visibleHeight = cameraRig.height * visibleHeightFraction
    let aspectRatio = Float(max(view.bounds.width, 1) / max(view.bounds.height, 1))
    let horizontalOffset = isCentered ? 0 : visibleHeight * aspectRatio * 0.2
    let stagedTopMargin = isCentered ? 0 : visibleHeight * 0.08
    let target = SIMD3<Float>(
        cameraRig.center.x - horizontalOffset,
        isCentered
            ? cameraRig.center.y
            : cameraRig.maximumY - visibleHeight / 2 + stagedTopMargin,
        cameraRig.center.z
    )
    let verticalFieldOfView: Float = 32
    let cameraDistance = visibleHeight / (2 * tan(verticalFieldOfView * .pi / 360))

    cameraRig.camera.camera = PerspectiveCameraComponent(
        near: 0.001,
        far: max(cameraRig.height * 4, 10),
        fieldOfViewInDegrees: verticalFieldOfView,
        fieldOfViewOrientation: .vertical
    )
    let targetPose = Entity()
    targetPose.look(
        at: target,
        from: SIMD3<Float>(cameraRig.center.x, target.y, cameraRig.maximumZ + cameraDistance),
        upVector: SIMD3<Float>(0, 1, 0),
        relativeTo: nil
    )

    if animated {
        cameraRig.camera.move(
            to: targetPose.transform,
            relativeTo: nil,
            duration: 0.35,
            timingFunction: .easeInOut
        )
    } else {
        cameraRig.camera.transform = targetPose.transform
    }
}

@Observable
@MainActor
private final class RocketCardSnapshotStore {
    static let shared = RocketCardSnapshotStore()

    private(set) var snapshots: [String: UIImage] = [:]
    private var renderingScenes: Set<String> = []

    func claimRenderer(for sceneName: String) -> Bool {
        guard snapshots[sceneName] == nil, !renderingScenes.contains(sceneName) else {
            return false
        }

        renderingScenes.insert(sceneName)
        return true
    }

    func complete(_ image: UIImage, for sceneName: String) {
        snapshots[sceneName] = image
        renderingScenes.remove(sceneName)
    }

    func cancelRendering(_ sceneName: String) {
        renderingScenes.remove(sceneName)
    }
}

@MainActor
private func rocketDirectionalLight(position: SIMD3<Float>, intensity: Float) -> Entity {
    let light = Entity()
    light.components.set(DirectionalLightComponent(color: .white, intensity: intensity))
    light.look(at: .zero, from: position, relativeTo: nil)
    return light
}

@MainActor
private final class RocketEntityCache {
    static let shared = RocketEntityCache()

    private var prototypes: [String: Entity] = [:]
    private var loadingTasks: [String: Task<Entity, Error>] = [:]

    func preload(sceneName: String) async throws {
        _ = try await prototype(sceneName: sceneName)
    }

    func clone(sceneName: String) async throws -> Entity {
        try await prototype(sceneName: sceneName).clone(recursive: true)
    }

    private func prototype(sceneName: String) async throws -> Entity {
        if let prototype = prototypes[sceneName] {
            return prototype
        }

        if let loadingTask = loadingTasks[sceneName] {
            return try await loadingTask.value
        }

        let loadingTask = Task { @MainActor in
            try await Entity(named: sceneName, in: overtureRocketsBundle)
        }
        loadingTasks[sceneName] = loadingTask

        do {
            let prototype = try await loadingTask.value
            prototypes[sceneName] = prototype
            loadingTasks[sceneName] = nil
            return prototype
        } catch {
            loadingTasks[sceneName] = nil
            throw error
        }
    }
}

private enum RocketModelAsset {
    case falcon9
    case falconHeavy
    case starship

    init?(vehicle: String) {
        let normalizedName = vehicle.lowercased()

        if normalizedName.contains("falcon heavy") {
            self = .falconHeavy
        } else if normalizedName.contains("starship") || normalizedName.contains("super heavy") {
            self = .starship
        } else if normalizedName.contains("falcon 9") {
            self = .falcon9
        } else {
            return nil
        }
    }

    var sceneName: String {
        switch self {
        case .falcon9:
            "Falcon 9"
        case .falconHeavy:
            "Falcon Heavy"
        case .starship:
            "Starship"
        }
    }
}

#Preview {
    RocketModelView(vehicle: "Falcon Heavy")
        .frame(width: 220, height: 420)
        .padding()
        .background(OvertureTheme.ink)
}
