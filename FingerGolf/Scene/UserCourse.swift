import Foundation

struct UserCourse: Codable, Identifiable {
    var id: UUID
    var definition: CourseDefinition
    var authorName: String
    var authorID: String
    var createdDate: Date
    var cloudRecordID: String?

    // Community metadata
    var playCount: Int
    var averageStrokes: Double

    init(definition: CourseDefinition,
         authorName: String = "Anonymous",
         authorID: String = "",
         createdDate: Date = Date()) {
        self.id = UUID()
        self.definition = definition
        self.authorName = authorName
        self.authorID = authorID
        self.createdDate = createdDate
        self.playCount = 0
        self.averageStrokes = 0.0
    }
}
