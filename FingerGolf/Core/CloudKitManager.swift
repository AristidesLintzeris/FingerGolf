import CloudKit
import Combine

class CloudKitManager: ObservableObject {

    static let shared = CloudKitManager()

    private lazy var container = CKContainer.default()
    private lazy var publicDB: CKDatabase = container.publicCloudDatabase

    @Published var communityCourses: [UserCourse] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    struct LeaderboardEntry: Identifiable {
        let id = UUID()
        let playerName: String
        let strokes: Int
        let date: Date
    }

    private init() {}

    // MARK: - Publish Course

    func publishCourse(_ userCourse: UserCourse) async throws -> CKRecord {
        let record = CKRecord(recordType: "Course")
        record["name"] = userCourse.definition.name as CKRecordValue
        record["par"] = userCourse.definition.par as CKRecordValue
        record["authorName"] = userCourse.authorName as CKRecordValue
        record["authorID"] = userCourse.authorID as CKRecordValue
        record["createdDate"] = userCourse.createdDate as CKRecordValue
        record["playCount"] = 0 as CKRecordValue
        record["averageStrokes"] = 0.0 as CKRecordValue
        record["downloadCount"] = 0 as CKRecordValue

        let encoder = JSONEncoder()
        let definitionData = try encoder.encode(userCourse.definition)
        let definitionJSON = String(data: definitionData, encoding: .utf8) ?? ""
        record["definitionJSON"] = definitionJSON as CKRecordValue

        let savedRecord = try await publicDB.save(record)
        return savedRecord
    }

    // MARK: - Fetch Community Courses

    func fetchCommunityCourses(sortBy: CommunitySortOrder = .newest) async {
        await MainActor.run { isLoading = true }

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Course", predicate: predicate)

        switch sortBy {
        case .newest:
            query.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        case .popular:
            query.sortDescriptors = [NSSortDescriptor(key: "downloadCount", ascending: false)]
        case .bestAverage:
            query.sortDescriptors = [NSSortDescriptor(key: "averageStrokes", ascending: true)]
        }

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 50)
            let courses = results.compactMap { _, result -> UserCourse? in
                guard case .success(let record) = result else { return nil }
                return userCourseFromRecord(record)
            }
            await MainActor.run {
                self.communityCourses = courses
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // MARK: - Search

    func searchCourses(query searchText: String) async {
        await MainActor.run { isLoading = true }

        let predicate = NSPredicate(format: "name CONTAINS %@", searchText)
        let query = CKQuery(recordType: "Course", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "downloadCount", ascending: false)]

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 50)
            let courses = results.compactMap { _, result -> UserCourse? in
                guard case .success(let record) = result else { return nil }
                return userCourseFromRecord(record)
            }
            await MainActor.run {
                self.communityCourses = courses
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // MARK: - Random Course ("Surprise Me")

    func fetchRandomCourse() async -> UserCourse? {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Course", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 50)
            let courses = results.compactMap { _, result -> UserCourse? in
                guard case .success(let record) = result else { return nil }
                return userCourseFromRecord(record)
            }
            return courses.randomElement()
        } catch {
            return nil
        }
    }

    // MARK: - Submit Score

    func submitScore(courseRecordName: String, strokes: Int, playerName: String) async throws {
        let record = CKRecord(recordType: "Score")
        let courseRef = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: courseRecordName),
            action: .deleteSelf
        )
        record["courseRef"] = courseRef as CKRecordValue
        record["strokes"] = strokes as CKRecordValue
        record["playerName"] = playerName as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue

        try await publicDB.save(record)

        await incrementPlayCount(courseRecordName: courseRecordName, strokes: strokes)
    }

    // MARK: - Increment Download Count

    func incrementDownloadCount(courseRecordName: String) async {
        let recordID = CKRecord.ID(recordName: courseRecordName)
        do {
            let record = try await publicDB.record(for: recordID)
            let currentCount = record["downloadCount"] as? Int ?? 0
            record["downloadCount"] = (currentCount + 1) as CKRecordValue
            try await publicDB.save(record)
        } catch {
            print("CloudKit: Failed to increment download count: \(error)")
        }
    }

    // MARK: - Fetch Leaderboard

    func fetchLeaderboard(courseRecordName: String) async {
        let courseRef = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: courseRecordName),
            action: .none
        )
        let predicate = NSPredicate(format: "courseRef == %@", courseRef)
        let query = CKQuery(recordType: "Score", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "strokes", ascending: true)]

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 10)
            let entries = results.compactMap { _, result -> LeaderboardEntry? in
                guard case .success(let record) = result,
                      let name = record["playerName"] as? String,
                      let strokes = record["strokes"] as? Int,
                      let date = record["timestamp"] as? Date
                else { return nil }
                return LeaderboardEntry(playerName: name, strokes: strokes, date: date)
            }
            await MainActor.run {
                self.leaderboard = entries
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    private func userCourseFromRecord(_ record: CKRecord) -> UserCourse? {
        guard let definitionJSON = record["definitionJSON"] as? String,
              let data = definitionJSON.data(using: .utf8),
              let definition = try? JSONDecoder().decode(CourseDefinition.self, from: data),
              let authorName = record["authorName"] as? String
        else { return nil }

        var course = UserCourse(
            definition: definition,
            authorName: authorName,
            authorID: record["authorID"] as? String ?? "",
            createdDate: record["createdDate"] as? Date ?? Date()
        )
        course.cloudRecordID = record.recordID.recordName
        course.playCount = record["playCount"] as? Int ?? 0
        course.averageStrokes = record["averageStrokes"] as? Double ?? 0
        return course
    }

    private func incrementPlayCount(courseRecordName: String, strokes: Int) async {
        let recordID = CKRecord.ID(recordName: courseRecordName)
        do {
            let record = try await publicDB.record(for: recordID)
            let currentCount = record["playCount"] as? Int ?? 0
            let currentAvg = record["averageStrokes"] as? Double ?? 0
            let newCount = currentCount + 1
            let newAvg = (currentAvg * Double(currentCount) + Double(strokes)) / Double(newCount)
            record["playCount"] = newCount as CKRecordValue
            record["averageStrokes"] = newAvg as CKRecordValue
            try await publicDB.save(record)
        } catch {
            print("CloudKit: Failed to increment play count: \(error)")
        }
    }

    // MARK: - User Identity

    func fetchPlayerName() async -> String {
        do {
            let userID = try await container.userRecordID()
            let identity = try await container.userIdentity(forUserRecordID: userID)
            if let components = identity?.nameComponents {
                return PersonNameComponentsFormatter.localizedString(from: components, style: .short)
            }
        } catch {
            // Fallback
        }
        return "Anonymous"
    }
}

enum CommunitySortOrder {
    case newest
    case popular
    case bestAverage
}
