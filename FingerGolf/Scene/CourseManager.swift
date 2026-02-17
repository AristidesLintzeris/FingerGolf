import SceneKit

class CourseManager {

    private(set) var courses: [CourseDefinition] = []
    private let courseBuilder = CourseBuilder()
    var currentCourseIndex: Int = 0

    init() {
        loadCourses()
    }

    // MARK: - Loading

    private func loadCourses() {
        // Try loading from JSON bundle
        if let url = Bundle.main.url(forResource: "Courses", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([CourseDefinition].self, from: data) {
            courses = decoded
        }

        // If no JSON found, use built-in courses
        if courses.isEmpty {
            courses = CourseManager.builtInCourses
        }
    }

    // MARK: - Course Access

    var currentCourse: CourseDefinition? {
        guard currentCourseIndex < courses.count else { return nil }
        return courses[currentCourseIndex]
    }

    var hasNextCourse: Bool {
        currentCourseIndex + 1 < courses.count
    }

    func advanceToNextCourse() -> Bool {
        guard hasNextCourse else { return false }
        currentCourseIndex += 1
        return true
    }

    func resetToFirstCourse() {
        currentCourseIndex = 0
    }

    func appendCourse(_ definition: CourseDefinition) {
        courses.append(definition)
    }

    // MARK: - Building

    func buildCurrentCourse() -> SCNNode? {
        guard let definition = currentCourse else { return nil }
        return courseBuilder.buildCourse(from: definition)
    }

    func buildCourse(at index: Int) -> SCNNode? {
        guard index < courses.count else { return nil }
        return courseBuilder.buildCourse(from: courses[index])
    }

    // MARK: - Built-in Courses

    static let builtInCourses: [CourseDefinition] = [
        // Level 1: "The Putt" - Par 1, straight line
        CourseDefinition(
            name: "The Putt",
            par: 1,
            pieces: [
                PiecePlacement(model: "end", x: 0, z: 0, rotation: 180),
                PiecePlacement(model: "straight", x: 0, z: 1),
                PiecePlacement(model: "straight", x: 0, z: 2),
                PiecePlacement(model: "end", x: 0, z: 3),
            ],
            ballStart: GridPosition(x: 0, z: 0),
            holePosition: GridPosition(x: 0, z: 3)
        ),
        // Level 2: "Split Path" - Par 2, windmill + castle + split paths
        CourseDefinition(
            name: "Split Path",
            par: 2,
            pieces: [
                PiecePlacement(model: "end", x: 0, z: 0, rotation: 180),
                PiecePlacement(model: "windmill", x: 0, z: 1, rotation: 180),
                PiecePlacement(model: "round-corner-a", x: -2, z: 2, rotation: 180),
                PiecePlacement(model: "castle", x: -1, z: 2, rotation: 90),
                PiecePlacement(model: "split-t", x: 0, z: 2),
                PiecePlacement(model: "split-start", x: 1, z: 2, rotation: 270),
                PiecePlacement(model: "round-corner-a", x: 2, z: 2, rotation: 90),
                PiecePlacement(model: "round-corner-a", x: -2, z: 3, rotation: 270),
                PiecePlacement(model: "spline-default", x: -1, z: 3, rotation: 90),
                PiecePlacement(model: "wall-left", x: 0, z: 3, rotation: 90),
                PiecePlacement(model: "split-start", x: 1, z: 3, rotation: 90),
                PiecePlacement(model: "round-corner-a", x: 2, z: 3),
            ],
            ballStart: GridPosition(x: 0, z: 0),
            holePosition: GridPosition(x: 0, z: 3)
        ),
        // Level 3: "The Gauntlet" - Par 3, windmill + castle + skew corners + gaps
        CourseDefinition(
            name: "The Gauntlet",
            par: 3,
            pieces: [
                PiecePlacement(model: "end", x: 0, z: 0, rotation: 180),
                PiecePlacement(model: "windmill", x: 0, z: 1, rotation: 180),
                PiecePlacement(model: "skew-corner", x: -2, z: 2, rotation: 180),
                PiecePlacement(model: "castle", x: -1, z: 2, rotation: 90),
                PiecePlacement(model: "split-t", x: 0, z: 2),
                PiecePlacement(model: "straight", x: 1, z: 2, rotation: 90),
                PiecePlacement(model: "skew-corner", x: 2, z: 2, rotation: 90),
                PiecePlacement(model: "skew-corner", x: -2, z: 3, rotation: 270),
                PiecePlacement(model: "spline-default", x: -1, z: 3, rotation: 90),
                PiecePlacement(model: "wall-left", x: 0, z: 3, rotation: 90),
                PiecePlacement(model: "split-start", x: 1, z: 3, rotation: 90),
                PiecePlacement(model: "skew-corner", x: 2, z: 3),
            ],
            ballStart: GridPosition(x: 0, z: 0),
            holePosition: GridPosition(x: 0, z: 3)
        ),
        // Level 4: "Wavy Greens" - Par 4, round corner-b variations
        CourseDefinition(
            name: "Wavy Greens",
            par: 4,
            pieces: [
                PiecePlacement(model: "corner", x: 0, z: 0, rotation: 180),
                PiecePlacement(model: "round-corner-b", x: 1, z: 0, rotation: 90),
                PiecePlacement(model: "round-corner-b", x: 2, z: 0, rotation: 180),
                PiecePlacement(model: "round-corner-b", x: 3, z: 0, rotation: 90),
                PiecePlacement(model: "corner", x: 4, z: 0, rotation: 90),
                PiecePlacement(model: "corner", x: 0, z: 1, rotation: 270),
                PiecePlacement(model: "round-corner-b", x: 1, z: 1, rotation: 270),
                PiecePlacement(model: "round-corner-b", x: 2, z: 1),
                PiecePlacement(model: "round-corner-b", x: 3, z: 1, rotation: 270),
                PiecePlacement(model: "round-corner-b", x: 4, z: 1),
            ],
            ballStart: GridPosition(x: 0, z: 1),
            holePosition: GridPosition(x: 4, z: 0)
        ),
        // Level 5: "Mountain Pass" - Par 5, ramps + hills + square corners
        CourseDefinition(
            name: "Mountain Pass",
            par: 5,
            pieces: [
                PiecePlacement(model: "corner", x: -4, z: -1, rotation: 180),
                PiecePlacement(model: "ramp-low", x: -3, z: -1, rotation: 90),
                PiecePlacement(model: "ramp-large", x: -2, z: -1, rotation: 90),
                PiecePlacement(model: "square-corner-a", x: -1, z: -1, rotation: 180),
                PiecePlacement(model: "ramp-large-side", x: 0, z: -1, rotation: 90),
                PiecePlacement(model: "end", x: 1, z: -1, rotation: 270),
                PiecePlacement(model: "straight", x: 2, z: -1, rotation: 270),
                PiecePlacement(model: "round-corner-b", x: 3, z: -1, rotation: 90),
                PiecePlacement(model: "corner", x: -4, z: 0, rotation: 270),
                PiecePlacement(model: "ramp-square", x: -3, z: 0, rotation: 90),
                PiecePlacement(model: "hill-round", x: -2, z: 0, rotation: 90),
                PiecePlacement(model: "square-corner-a", x: -1, z: 0),
                PiecePlacement(model: "round-corner-a", x: 0, z: 0, rotation: 180),
                PiecePlacement(model: "square-corner-a", x: 1, z: 0, rotation: 90),
                PiecePlacement(model: "round-corner-b", x: 2, z: 0, rotation: 180),
                PiecePlacement(model: "corner", x: 3, z: 0),
                PiecePlacement(model: "round-corner-a", x: 0, z: 1, rotation: 270),
                PiecePlacement(model: "side", x: 1, z: 1, rotation: 270),
                PiecePlacement(model: "round-corner-a", x: 2, z: 1),
            ],
            ballStart: GridPosition(x: -4, z: 0),
            holePosition: GridPosition(x: 3, z: 0)
        ),
        // Level 6: "The Fortress" - Par 6, multi-level with ramps + blocks
        CourseDefinition(
            name: "The Fortress",
            par: 6,
            pieces: [
                PiecePlacement(model: "corner", x: 4, z: -3, rotation: 180),
                PiecePlacement(model: "corner", x: 5, z: -3, rotation: 90),
                PiecePlacement(model: "corner", x: 4, z: -2, rotation: 270),
                PiecePlacement(model: "corner", x: 5, z: -2, rotation: 90),
                PiecePlacement(model: "ramp", x: 5, z: -1),
                PiecePlacement(model: "end", x: 0, z: 0, rotation: 270),
                PiecePlacement(model: "corner", x: 1, z: 0, rotation: 90),
                PiecePlacement(model: "skew-corner", x: 2, z: 0, rotation: 180),
                PiecePlacement(model: "skew-corner", x: 3, z: 0, rotation: 90),
                PiecePlacement(model: "block", x: 4, z: 0, rotation: 90),
                PiecePlacement(model: "ramp", x: 5, z: 0, rotation: 180),
                PiecePlacement(model: "end", x: 6, z: 0, rotation: 180),
                PiecePlacement(model: "corner", x: 0, z: 1, rotation: 180),
                PiecePlacement(model: "corner", x: 1, z: 1),
                PiecePlacement(model: "ramp", x: 2, z: 1),
                PiecePlacement(model: "skew-corner", x: 3, z: 1, rotation: 270),
                PiecePlacement(model: "straight", x: 4, z: 1, rotation: 270),
                PiecePlacement(model: "side", x: 5, z: 1, rotation: 270),
                PiecePlacement(model: "corner", x: 6, z: 1),
                PiecePlacement(model: "corner", x: 0, z: 2, rotation: 270),
                PiecePlacement(model: "square-corner-a", x: 1, z: 2, rotation: 90),
                PiecePlacement(model: "ramp", x: 2, z: 2, rotation: 180),
                PiecePlacement(model: "block", x: 0, z: 3, rotation: 270),
                PiecePlacement(model: "corner", x: 1, z: 3, rotation: 270),
                PiecePlacement(model: "corner", x: 2, z: 3),
            ],
            ballStart: GridPosition(x: 0, z: 0),
            holePosition: GridPosition(x: 5, z: -3)
        ),
        // Level 7: "Split Corridor" - Par 7, tunnel + walls + open area
        CourseDefinition(
            name: "Split Corridor",
            par: 7,
            pieces: [
                PiecePlacement(model: "corner", x: -2, z: -2, rotation: 180),
                PiecePlacement(model: "side", x: -1, z: -2, rotation: 90),
                PiecePlacement(model: "side", x: 0, z: -2, rotation: 90),
                PiecePlacement(model: "side", x: 1, z: -2, rotation: 90),
                PiecePlacement(model: "corner", x: 2, z: -2, rotation: 90),
                PiecePlacement(model: "side", x: -2, z: -1, rotation: 180),
                PiecePlacement(model: "open", x: -1, z: -1, rotation: 90),
                PiecePlacement(model: "open", x: 0, z: -1, rotation: 90),
                PiecePlacement(model: "open", x: 1, z: -1, rotation: 90),
                PiecePlacement(model: "side", x: 2, z: -1),
                PiecePlacement(model: "corner", x: -8, z: 0, rotation: 180),
                PiecePlacement(model: "side", x: -7, z: 0, rotation: 90),
                PiecePlacement(model: "tunnel-double", x: -6, z: 0, rotation: 270),
                PiecePlacement(model: "split", x: -5, z: 0, rotation: 270),
                PiecePlacement(model: "split", x: -4, z: 0, rotation: 270),
                PiecePlacement(model: "split", x: -3, z: 0, rotation: 270),
                PiecePlacement(model: "split-walls-to-open", x: -2, z: 0, rotation: 90),
                PiecePlacement(model: "open", x: -1, z: 0, rotation: 90),
                PiecePlacement(model: "open", x: 0, z: 0, rotation: 90),
                PiecePlacement(model: "open", x: 1, z: 0, rotation: 90),
                PiecePlacement(model: "side", x: 2, z: 0),
                PiecePlacement(model: "corner", x: -8, z: 1, rotation: 270),
                PiecePlacement(model: "wall-left", x: -7, z: 1, rotation: 270),
                PiecePlacement(model: "wall-right", x: -6, z: 1, rotation: 270),
                PiecePlacement(model: "wall-left", x: -5, z: 1, rotation: 270),
                PiecePlacement(model: "wall-right", x: -4, z: 1, rotation: 270),
                PiecePlacement(model: "wall-left", x: -3, z: 1, rotation: 90),
                PiecePlacement(model: "side", x: -2, z: 1, rotation: 180),
                PiecePlacement(model: "open", x: -1, z: 1, rotation: 90),
                PiecePlacement(model: "open", x: 0, z: 1, rotation: 90),
                PiecePlacement(model: "open", x: 1, z: 1, rotation: 90),
                PiecePlacement(model: "side", x: 2, z: 1),
                PiecePlacement(model: "corner", x: -2, z: 2, rotation: 270),
                PiecePlacement(model: "side", x: -1, z: 2, rotation: 270),
                PiecePlacement(model: "side", x: 0, z: 2, rotation: 270),
                PiecePlacement(model: "side", x: 1, z: 2, rotation: 270),
                PiecePlacement(model: "corner", x: 2, z: 2),
            ],
            ballStart: GridPosition(x: 0, z: 0),
            holePosition: GridPosition(x: -3, z: 1)
        ),
    ]
}
