import OvertureRockets
import Observation
import RealityKit
import SwiftUI
import UIKit

private let rocketVerticalFieldOfView: Float = 45

struct RocketModelView: View {
    let vehicle: String

    @State private var didLoad = false
    @State private var loadFailed = false

    static func supports(vehicle: String, spacecraft: String? = nil) -> Bool {
        RocketModelAsset(vehicle: vehicle, spacecraft: spacecraft) != nil
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
                        let lightingRig = try await rocketLightingRig(receiving: entity)
                        content.add(entity)
                        content.add(lightingRig)
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
    let spacecraft: String?

    init(vehicle: String, spacecraft: String? = nil) {
        self.vehicle = vehicle
        self.spacecraft = spacecraft
    }

    @State private var snapshotStore = RocketCardSnapshotStore.shared
    @State private var ownsRenderer = false

    var body: some View {
        if let asset = RocketModelAsset(vehicle: vehicle, spacecraft: spacecraft) {
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
    let spacecraft: String?
    let isCentered: Bool

    init(vehicle: String, spacecraft: String? = nil, isCentered: Bool) {
        self.vehicle = vehicle
        self.spacecraft = spacecraft
        self.isCentered = isCentered
    }

    var body: some View {
        if let asset = RocketModelAsset(vehicle: vehicle, spacecraft: spacecraft) {
            RocketLivePerspectiveView(
                sceneName: asset.sceneName,
                isCentered: isCentered
            )
                .accessibilityLabel("3D model of \(vehicle)")
                .accessibilityHint("Drag horizontally to spin the rocket. In compact mode, drag vertically to tilt it.")
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
        view.accessibilityHint = "Drag horizontally to spin the rocket. In compact mode, drag vertically to tilt it."
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
        coordinator.inertiaTask?.cancel()
        coordinator.removeGestures(from: uiView)
        uiView.scene.anchors.removeAll()
    }

    @MainActor
    final class Coordinator: NSObject {
        var loadTask: Task<Void, Never>?
        var inertiaTask: Task<Void, Never>?
        var cameraRig: RocketCameraRig?
        private var appliedCenteredState: Bool?
        private var installedGestures: [UIGestureRecognizer] = []
        private var allowsPitch = false
        private var yaw: Float = 0
        private var pitch: Float = 0
        private var panStartYaw: Float = 0
        private var panStartPitch: Float = 0

        func installGestures(on view: ARView) {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            panGesture.maximumNumberOfTouches = 1

            installedGestures = [panGesture]
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
                inertiaTask?.cancel()
                panStartYaw = yaw
                panStartPitch = pitch
            case .changed:
                let translation = gesture.translation(in: view)
                yaw = wrappedAngle(
                    panStartYaw + Float(translation.x) * 0.008
                )
                pitch = allowsPitch
                    ? wrappedAngle(panStartPitch + Float(translation.y) * 0.006)
                    : 0
                modelPivot.orientation = modelOrientation(yaw: yaw, pitch: pitch)
            case .ended:
                startInertia(
                    velocity: gesture.velocity(in: view),
                    modelPivot: modelPivot
                )
            default:
                break
            }
        }

        func applyFraming(to view: ARView, isCentered: Bool) {
            guard appliedCenteredState != isCentered, let cameraRig else { return }
            let shouldAnimate = appliedCenteredState != nil
            let wasCentered = appliedCenteredState == true
            appliedCenteredState = isCentered
            allowsPitch = isCentered

            if wasCentered, !isCentered {
                inertiaTask?.cancel()
                resetPitch(in: cameraRig.modelPivot, animated: true)
            }

            frameDetailRocket(
                cameraRig,
                in: view,
                isCentered: isCentered,
                animated: shouldAnimate
            )
        }

        private func startInertia(velocity: CGPoint, modelPivot: Entity) {
            var yawVelocity = min(
                max(Float(velocity.x) * 0.008 * 0.28, -4),
                4
            )
            var pitchVelocity = allowsPitch
                ? min(max(Float(velocity.y) * 0.006 * 0.28, -2.8), 2.8)
                : 0

            guard abs(yawVelocity) > 0.05 || abs(pitchVelocity) > 0.05 else { return }

            inertiaTask?.cancel()
            inertiaTask = Task { @MainActor [weak self, weak modelPivot] in
                var previousTime = CACurrentMediaTime()

                while !Task.isCancelled,
                      abs(yawVelocity) > 0.02 || abs(pitchVelocity) > 0.02 {
                    try? await Task.sleep(nanoseconds: 16_000_000)
                    guard !Task.isCancelled, let self, let modelPivot else { return }

                    let currentTime = CACurrentMediaTime()
                    let elapsed = Float(min(currentTime - previousTime, 0.033))
                    previousTime = currentTime

                    yaw = wrappedAngle(yaw + yawVelocity * elapsed)
                    if allowsPitch {
                        pitch = wrappedAngle(pitch + pitchVelocity * elapsed)
                    } else {
                        pitch = 0
                        pitchVelocity = 0
                    }

                    modelPivot.orientation = modelOrientation(yaw: yaw, pitch: pitch)

                    let damping = exp(-4 * elapsed)
                    yawVelocity *= damping
                    pitchVelocity *= damping
                }
            }
        }

        private func resetPitch(in modelPivot: Entity, animated: Bool) {
            guard abs(pitch) > 0.0001 else { return }
            pitch = 0

            var transform = modelPivot.transform
            transform.rotation = modelOrientation(yaw: yaw, pitch: 0)

            if animated {
                modelPivot.move(
                    to: transform,
                    relativeTo: modelPivot.parent,
                    duration: 0.35,
                    timingFunction: .easeInOut
                )
            } else {
                modelPivot.transform = transform
            }
        }

        private func wrappedAngle(_ angle: Float) -> Float {
            angle.truncatingRemainder(dividingBy: 2 * .pi)
        }

        private func modelOrientation(yaw: Float, pitch: Float) -> simd_quatf {
            let yawRotation = simd_quatf(
                angle: yaw,
                axis: SIMD3<Float>(0, 1, 0)
            )
            let pitchRotation = simd_quatf(
                angle: pitch,
                axis: SIMD3<Float>(1, 0, 0)
            )
            return pitchRotation * yawRotation
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
    let verticalFieldOfView = rocketVerticalFieldOfView
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
    anchor.addChild(try await rocketLightingRig(receiving: entity))
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
    let verticalFieldOfView = rocketVerticalFieldOfView
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
private func rocketLightingRig(receiving entity: Entity) async throws -> Entity {
    let rig = Entity()
    let environment = try await RocketLightingEnvironment.shared.resource()
    rig.components.set(ImageBasedLightComponent(
        source: .single(environment),
        intensityExponent: -0.35
    ))
    entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: rig))

    // Neutral directional lights shape the rocket while the studio environment
    // supplies the long, bright reflections that make its glossy finish readable.
    rig.addChild(rocketDirectionalLight(
        color: .white,
        position: SIMD3<Float>(4, 6, 5),
        intensity: 2_400,
        castsShadow: true
    ))
    rig.addChild(rocketDirectionalLight(
        color: .white,
        position: SIMD3<Float>(-4, 1, 3),
        intensity: 180
    ))
    rig.addChild(rocketDirectionalLight(
        color: .white,
        position: SIMD3<Float>(-3, 4, -5),
        intensity: 900
    ))

    return rig
}

@MainActor
private func rocketDirectionalLight(
    color: UIColor,
    position: SIMD3<Float>,
    intensity: Float,
    castsShadow: Bool = false
) -> Entity {
    let light = Entity()
    light.components.set(DirectionalLightComponent(color: color, intensity: intensity))
    if castsShadow {
        light.components.set(DirectionalLightComponent.Shadow())
    }
    light.look(at: .zero, from: position, relativeTo: nil)
    return light
}

@MainActor
private final class RocketLightingEnvironment {
    static let shared = RocketLightingEnvironment()

    private var cachedResource: EnvironmentResource?

    func resource() async throws -> EnvironmentResource {
        if let cachedResource {
            return cachedResource
        }

        let resource = try await EnvironmentResource(
            equirectangular: neutralStudioImage(),
            withName: "Overture Neutral Studio"
        )
        cachedResource = resource
        return resource
    }

    private func neutralStudioImage() -> CGImage {
        let size = CGSize(width: 1_024, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.06, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            drawSoftbox(centerX: 190, width: 170, in: context, height: size.height)
            drawSoftbox(centerX: 730, width: 70, in: context, height: size.height)

            UIColor(white: 0.55, alpha: 1).setFill()
            context.fill(CGRect(x: 400, y: 28, width: 225, height: 52))
        }.cgImage!
    }

    private func drawSoftbox(
        centerX: CGFloat,
        width: CGFloat,
        in context: UIGraphicsImageRendererContext,
        height: CGFloat
    ) {
        for layer in stride(from: 5, through: 0, by: -1) {
            let expansion = CGFloat(layer) * 18
            let brightness = 1 - CGFloat(layer) * 0.105
            UIColor(white: brightness, alpha: 1).setFill()
            context.fill(CGRect(
                x: centerX - width / 2 - expansion,
                y: 0,
                width: width + expansion * 2,
                height: height
            ))
        }
    }
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
    case falcon9CrewDragon
    case falconHeavy
    case starship
    case alpha
    case electron

    init?(vehicle: String, spacecraft: String? = nil) {
        let normalizedName = vehicle.lowercased()
        let normalizedSpacecraft = spacecraft?.lowercased() ?? ""

        if normalizedName.contains("falcon 9") && normalizedSpacecraft.contains("crew dragon") {
            self = .falcon9CrewDragon
        } else if normalizedName.contains("falcon heavy") {
            self = .falconHeavy
        } else if normalizedName.contains("starship") || normalizedName.contains("super heavy") {
            self = .starship
        } else if normalizedName.contains("falcon 9") {
            self = .falcon9
        } else if normalizedName.contains("firefly alpha") || normalizedName == "alpha" {
            self = .alpha
        } else if normalizedName.contains("electron") {
            self = .electron
        } else {
            return nil
        }
    }

    var sceneName: String {
        switch self {
        case .falcon9:
            "Falcon 9"
        case .falcon9CrewDragon:
            "F9 Crew Dragon"
        case .falconHeavy:
            "Falcon Heavy"
        case .starship:
            "Starship"
        case .alpha:
            "Alpha"
        case .electron:
            "Electron"
        }
    }
}

#Preview {
    RocketModelView(vehicle: "Falcon Heavy")
        .frame(width: 220, height: 420)
        .padding()
        .background(OvertureTheme.ink)
}
