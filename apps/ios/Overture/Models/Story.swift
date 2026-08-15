import Foundation

struct Story: Identifiable, Hashable {
    let id: String
    let slug: String
    let title: String
    let deck: String
    let readTime: String
    let category: String
    let imageName: String
    let imageURL: URL?
    let byline: String
    let publishedAt: Date?
    let sections: [ArticleSection]

    init(
        id: String,
        slug: String? = nil,
        title: String,
        deck: String,
        readTime: String,
        category: String,
        imageName: String,
        imageURL: URL? = nil,
        byline: String = "Mara Bell",
        publishedAt: Date? = nil,
        sections: [ArticleSection] = []
    ) {
        self.id = id
        self.slug = slug ?? id
        self.title = title
        self.deck = deck
        self.readTime = readTime
        self.category = category
        self.imageName = imageName
        self.imageURL = imageURL
        self.byline = byline
        self.publishedAt = publishedAt
        self.sections = sections
    }

    static let quietFlight = Story(
        id: "quiet-flight",
        title: "The Shape of Quiet Flight",
        deck: "NASA’s experimental aircraft is testing whether supersonic travel can become quiet enough for cities.",
        readTime: "7 min read",
        category: "Aviation",
        imageName: "QuietFlight"
    )

    static let paperBattery = Story(
        id: "paper-battery",
        title: "A Battery Made From Paper",
        deck: "Engineers created a flexible cell from paper-based materials that could power a new wave of tiny devices.",
        readTime: "6 min read",
        category: "Materials",
        imageName: "PaperBattery"
    )

    static let laundryRobot = Story(
        id: "laundry-robot",
        title: "The Robot That Learned to Fold Laundry",
        deck: "A new AI model helps robots handle the unpredictable—one shirt at a time.",
        readTime: "8 min read",
        category: "Robotics",
        imageName: "LaundryRobot"
    )

    static let all: [Story] = [.quietFlight, .paperBattery, .laundryRobot]
}

enum ReadingDepth: Int, CaseIterable, Identifiable, Comparable {
    case glance
    case brief
    case standard
    case full

    var id: Self { self }

    var title: String {
        switch self {
        case .glance: "Glance"
        case .brief: "Brief"
        case .standard: "Standard"
        case .full: "Full"
        }
    }

    func readingTime(for story: Story?) -> String {
        switch self {
        case .glance: "1 min"
        case .brief: "3 min"
        case .standard: "5 min"
        case .full: story?.readTime.replacingOccurrences(of: " read", with: "") ?? "Full"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    func offset(by amount: Int) -> Self {
        let index = min(max(rawValue + amount, 0), Self.allCases.count - 1)
        return Self(rawValue: index) ?? self
    }
}

struct ArticleSection: Identifiable, Hashable {
    let id: String
    let heading: String?
    let glance: String
    let brief: String
    let standard: String
    let full: String

    func text(at depth: ReadingDepth) -> String {
        switch depth {
        case .glance: glance
        case .brief: brief
        case .standard: standard
        case .full: full
        }
    }
}

struct ArticleContent {
    let sections: [ArticleSection]

    static func placeholder(for story: Story) -> Self {
        if !story.sections.isEmpty {
            return ArticleContent(sections: story.sections)
        }

        switch story.id {
        case Story.paperBattery.id:
            return paperBattery
        case Story.laundryRobot.id:
            return laundryRobot
        default:
            return quietFlight
        }
    }

    private static let quietFlight = ArticleContent(sections: [
        ArticleSection(
            id: "quiet-flight-opening",
            heading: nil,
            glance: "NASA’s X-59 reshapes the sonic boom into a quieter thump, potentially reopening supersonic flight over land.",
            brief: "For more than half a century, the sonic boom made commercial supersonic flight incompatible with life below. NASA’s X-59 is designed around a different premise: reshape the pressure wave itself. Instead of one explosive crack, people on the ground should hear something closer to a distant car door.",
            standard: "For more than half a century, the sonic boom made commercial supersonic flight incompatible with life below. NASA’s X-59 is designed around a different premise: reshape the pressure wave itself. Its long needle nose prevents pressure waves from merging into one explosive crack. People on the ground should hear something closer to a distant car door.\n\nThe aircraft is not a passenger jet. It is an evidence-gathering machine built to answer whether communities can tolerate quiet supersonic flight.",
            full: "For more than half a century, the sonic boom made commercial supersonic flight incompatible with life below. NASA’s X-59 is designed around a different premise: reshape the pressure wave itself. Its long needle nose prevents pressure waves from merging into one explosive crack. People on the ground should hear something closer to a distant car door.\n\nThe aircraft is not a passenger jet. It is an evidence-gathering machine built to answer whether communities can tolerate quiet supersonic flight. That distinction matters: the engineering goal is not only to fly faster than sound, but to produce the kind of public data regulators would need before reconsidering long-standing limits."
        ),
        ArticleSection(
            id: "quiet-flight-shape",
            heading: "Engineering a gentler boom",
            glance: "A needle-like nose spreads pressure waves across time so they arrive as a muted sequence instead of a single boom.",
            brief: "Traditional supersonic aircraft create shock waves that combine before reaching the ground. The X-59’s unusual silhouette keeps those waves separated, turning a double boom into a muted sequence. Its shape is so specialized that the pilot uses cameras instead of a forward-facing window.",
            standard: "Traditional supersonic aircraft create strong shock waves that combine before reaching the ground. The X-59’s unusual silhouette keeps those waves separated, turning the familiar double boom into a muted sequence.\n\nThat design changes nearly everything around the aircraft. Its engine sits above the fuselage, and its nose is so long that a conventional forward-facing cockpit window would not work. The pilot instead sees through a high-resolution camera system.",
            full: "Traditional supersonic aircraft create strong shock waves that combine before reaching the ground. The X-59’s unusual silhouette keeps those waves separated, turning the familiar double boom into a muted sequence. Engineers model not just the loudness of the sound but its character, duration, and the way it changes across different weather conditions.\n\nThat design changes nearly everything around the aircraft. Its engine sits above the fuselage so its inlet does not disturb the carefully managed pressure pattern. Its nose is so long that a conventional forward-facing cockpit window would not work. The pilot instead sees through a high-resolution camera system assembled from multiple sensors."
        ),
        ArticleSection(
            id: "quiet-flight-next",
            heading: "The test is on the ground",
            glance: "The decisive result will come from communities beneath the flight path, not from the aircraft alone.",
            brief: "The next phase belongs to people on the ground. NASA plans to fly over selected communities, measure the sound, and ask residents what they experienced. Those responses could give regulators evidence for sound-based limits rather than an absolute ban on supersonic flight.",
            standard: "The next phase belongs to people on the ground. NASA plans to fly the X-59 over selected communities, measure the sound, and ask residents what they experienced. The results will combine acoustic instruments with thousands of subjective reactions.\n\nIf the tests match the simulations, regulators will have something they have never had before: evidence that sound limits, rather than absolute speed limits, could govern flight over land.",
            full: "The next phase belongs to people on the ground. NASA plans to fly the X-59 over selected communities, measure the sound, and ask residents what they experienced. The results will combine acoustic instruments with thousands of subjective reactions, because acceptability cannot be derived from decibels alone.\n\nIf the tests match the simulations, regulators will have something they have never had before: evidence that sound limits, rather than absolute speed limits, could govern flight over land. That would not guarantee a new generation of airliners, but it would remove one of the largest legal uncertainties standing in their way."
        )
    ])

    private static let paperBattery = ArticleContent(sections: [
        ArticleSection(
            id: "paper-battery-opening",
            heading: nil,
            glance: "Researchers built a flexible battery from paper-like materials that could safely power tiny disposable devices.",
            brief: "A thin square of paper can now produce enough electricity for a small sensor. Its layers use inexpensive, flexible materials and activate with a drop of water, suggesting a new power source for devices that do not need to live forever.",
            standard: "A thin square of paper can now produce enough electricity for a small sensor. Its layers use inexpensive, flexible materials and activate with a drop of water. The result is not meant to compete with the battery in a phone. It is designed for devices that are cheap, temporary, and increasingly everywhere.\n\nResearchers imagine diagnostic tests, environmental sensors, and smart packaging that can power themselves briefly and then leave less electronic waste behind.",
            full: "A thin square of paper can now produce enough electricity for a small sensor. Its layers use inexpensive, flexible materials and activate with a drop of water. The result is not meant to compete with the battery in a phone. It is designed for devices that are cheap, temporary, and increasingly everywhere.\n\nResearchers imagine diagnostic tests, environmental sensors, and smart packaging that can power themselves briefly and then leave less electronic waste behind. Billions of tiny connected objects could otherwise create a stream of batteries that are too small and dispersed to recycle economically."
        ),
        ArticleSection(
            id: "paper-battery-mechanism",
            heading: "A battery that wakes up wet",
            glance: "Water dissolves salts in the paper, allowing ions to move and the battery to begin producing current.",
            brief: "The dry battery remains dormant during storage. Water dissolves salts embedded in the paper, allowing ions to move between printed conductive layers. That reaction produces current without a rigid metal casing.",
            standard: "The dry battery remains dormant during storage. Water dissolves salts embedded in the paper, allowing ions to move between printed conductive layers. That reaction produces current without a rigid metal casing.\n\nBecause the active materials can be printed, the battery can take unusual shapes and be manufactured alongside the sensor it powers. Designers could tune its size to a product instead of designing the product around a standard cell.",
            full: "The dry battery remains dormant during storage. Water dissolves salts embedded in the paper, allowing ions to move between printed conductive layers. That reaction produces current without a rigid metal casing. The prototype can be activated deliberately or by the liquid a diagnostic test is already meant to detect.\n\nBecause the active materials can be printed, the battery can take unusual shapes and be manufactured alongside the sensor it powers. Designers could tune its size to a product instead of designing the product around a standard cell, reducing unused capacity and material."
        ),
        ArticleSection(
            id: "paper-battery-next",
            heading: "Small power, large consequence",
            glance: "The challenge is scaling production while proving that every ingredient is genuinely safe to discard.",
            brief: "The next hurdle is manufacturing consistency. A laboratory cell that works once must become a printed product that works after months on a shelf. Researchers also need to account for every ink, coating, and adhesive before calling the complete device disposable.",
            standard: "The next hurdle is manufacturing consistency. A laboratory cell that works once must become a printed product that works after months on a shelf. Researchers also need to account for every ink, coating, and adhesive before calling the complete device disposable.\n\nThe opportunity is less about a spectacular battery than eliminating millions of quiet, wasteful ones.",
            full: "The next hurdle is manufacturing consistency. A laboratory cell that works once must become a printed product that works after months on a shelf. Researchers also need to account for every ink, coating, and adhesive before calling the complete device disposable or biodegradable.\n\nThe opportunity is less about a spectacular battery than eliminating millions of quiet, wasteful ones. If the power source can become part of the printed object itself, entire categories of short-lived electronics could be designed around graceful disappearance rather than eventual collection."
        )
    ])

    private static let laundryRobot = ArticleContent(sections: [
        ArticleSection(
            id: "laundry-robot-opening",
            heading: nil,
            glance: "A new robot learns to fold unfamiliar clothes by reasoning about fabric instead of memorizing one perfect motion.",
            brief: "Laundry exposes a stubborn weakness in robotics: every shirt collapses into a different shape. A new system learns to identify corners, sleeves, and layers, then revises its plan whenever the fabric moves unexpectedly.",
            standard: "Laundry exposes a stubborn weakness in robotics: every shirt collapses into a different shape. A new system learns to identify corners, sleeves, and layers, then revises its plan whenever the fabric moves unexpectedly.\n\nThe goal is not a machine that perfectly repeats one fold. It is a robot that can recover from the small surprises that fill an ordinary home.",
            full: "Laundry exposes a stubborn weakness in robotics: every shirt collapses into a different shape. A new system learns to identify corners, sleeves, and layers, then revises its plan whenever the fabric moves unexpectedly. Unlike a rigid factory part, cloth hides its own geometry as it bends and overlaps.\n\nThe goal is not a machine that perfectly repeats one fold. It is a robot that can recover from the small surprises that fill an ordinary home: an inside-out sleeve, a towel beneath a shirt, or a grasp that lands a few centimeters away from its target."
        ),
        ArticleSection(
            id: "laundry-robot-learning",
            heading: "Learning the shape beneath the wrinkles",
            glance: "The model predicts how each grasp will change the fabric and checks the result before choosing another move.",
            brief: "Cameras estimate the garment’s hidden structure. The model predicts what a grasp will reveal, performs the move, and looks again. Folding becomes a sequence of small, corrected decisions rather than one long choreography.",
            standard: "Cameras estimate the garment’s hidden structure. The model predicts what a grasp will reveal, performs the move, and looks again. Folding becomes a sequence of small, corrected decisions rather than one long choreography.\n\nThis feedback loop makes the system slower than a specialized factory machine but far more adaptable. A failed grasp becomes new information instead of the end of the task.",
            full: "Cameras estimate the garment’s hidden structure. The model predicts what a grasp will reveal, performs the move, and looks again. Folding becomes a sequence of small, corrected decisions rather than one long choreography. The system has been trained on many arrangements, but it still has to infer what it is seeing in the moment.\n\nThis feedback loop makes the system slower than a specialized factory machine but far more adaptable. A failed grasp becomes new information instead of the end of the task. That capacity to notice and repair small mistakes may matter more for home robotics than raw speed."
        ),
        ArticleSection(
            id: "laundry-robot-next",
            heading: "From demonstration to useful machine",
            glance: "The robot remains too slow and expensive for most homes, but its recovery skills could transfer to many household tasks.",
            brief: "The prototype remains too slow and expensive for most homes. Its larger value may be the general skill underneath: manipulating objects that never present the same shape twice. Bedding, cables, groceries, and cleanup all pose related problems.",
            standard: "The prototype remains too slow and expensive for most homes. Its larger value may be the general skill underneath: manipulating objects that never present the same shape twice. Bedding, cables, groceries, and cleanup all pose related problems.\n\nA useful household robot will need to notice uncertainty, try something, and recover without asking a person to reset the scene.",
            full: "The prototype remains too slow and expensive for most homes. Its larger value may be the general skill underneath: manipulating objects that never present the same shape twice. Bedding, cables, groceries, and cleanup all pose related problems.\n\nA useful household robot will need to notice uncertainty, try something, and recover without asking a person to reset the scene. Laundry is valuable precisely because it is mundane: success would show that robots are becoming capable of working in the untidy physical world people actually inhabit."
        )
    ])
}

enum Edition: String, CaseIterable, Identifiable {
    case tomorrow
    case cleanEnergy
    case futureOfLiving

    var id: Self { self }

    var title: String {
        switch self {
        case .tomorrow: "Tomorrow Issue"
        case .cleanEnergy: "Clean Energy"
        case .futureOfLiving: "Future of Living"
        }
    }
}
