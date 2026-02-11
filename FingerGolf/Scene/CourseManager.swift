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
        // Course 1: "First Putt" - Straight line
        CourseDefinition(
            name: "First Putt",
            par: 2,
            pieces: [
                PiecePlacement(model: "end", x: 0, z: 0),
                PiecePlacement(model: "straight", x: 0, z: 1),
                PiecePlacement(model: "straight", x: 0, z: 2),
                PiecePlacement(model: "end", x: 0, z: 3),
            ],
            ballStart: GridPosition(x: 0, z: 0),
            holePosition: GridPosition(x: 0, z: 3)
        ),
        // Course 2: "The Bend" - L-shaped with a corner
        CourseDefinition(
            name: "The Bend",
            par: 3,
            pieces: [
                PiecePlacement(model: "end", x: 0, z: 0),
                PiecePlacement(model: "straight", x: 0, z: 1),
                PiecePlacement(model: "corner", x: 0, z: 2, rotation: 0),
                PiecePlacement(model: "straight", x: 1, z: 2),
                PiecePlacement(model: "end", x: 2, z: 2),
            ],
            ballStart: GridPosition(x: 0, z: 0),
            holePosition: GridPosition(x: 2, z: 2)
        ),
        // Course 3: "Obstacle Run" - Straight with obstacle
        CourseDefinition(
            name: "Obstacle Run",
            par: 3,
            pieces: [
                PiecePlacement(model: "end", x: 0, z: 0),
                PiecePlacement(model: "straight", x: 0, z: 1),
                PiecePlacement(model: "straight", x: 0, z: 2),
                PiecePlacement(model: "straight", x: 0, z: 3),
                PiecePlacement(model: "straight", x: 0, z: 4),
                PiecePlacement(model: "end", x: 0, z: 5),
            ],
            ballStart: GridPosition(x: 0, z: 0),
            holePosition: GridPosition(x: 0, z: 5)
        ),
        // Course 4: "Up and Over" - Ramp course
        CourseDefinition(
            name: "Up and Over",
            par: 4,
            pieces: [
                PiecePlacement(model: "end", x: 0, z: 0),
                PiecePlacement(model: "straight", x: 0, z: 1),
                PiecePlacement(model: "ramp-low", x: 0, z: 2),
                PiecePlacement(model: "straight", x: 0, z: 3),
                PiecePlacement(model: "ramp-low", x: 0, z: 4, rotation: 180),
                PiecePlacement(model: "straight", x: 0, z: 5),
                PiecePlacement(model: "end", x: 0, z: 6),
            ],
            ballStart: GridPosition(x: 0, z: 0),
            holePosition: GridPosition(x: 0, z: 6)
        ),
        // Course 5: "Windmill Challenge" - S-curve with windmill
        CourseDefinition(
            name: "Windmill Challenge",
            par: 5,
            pieces: [
                PiecePlacement(model: "end", x: 0, z: 0),
                PiecePlacement(model: "straight", x: 0, z: 1),
                PiecePlacement(model: "corner", x: 0, z: 2, rotation: 0),
                PiecePlacement(model: "straight", x: 1, z: 2),
                PiecePlacement(model: "straight", x: 2, z: 2),
                PiecePlacement(model: "corner", x: 3, z: 2, rotation: 90),
                PiecePlacement(model: "straight", x: 3, z: 3),
                PiecePlacement(model: "straight", x: 3, z: 4),
                PiecePlacement(model: "end", x: 3, z: 5),
            ],
            ballStart: GridPosition(x: 0, z: 0),
            holePosition: GridPosition(x: 3, z: 5)
        ),
    ]
}
