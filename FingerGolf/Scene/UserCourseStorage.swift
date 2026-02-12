import Foundation

class UserCourseStorage {

    static let shared = UserCourseStorage()

    private let directoryName = "UserCourses"

    private var storageDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(directoryName)
    }

    private init() {
        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - CRUD

    func save(_ course: UserCourse) throws {
        let data = try JSONEncoder().encode(course)
        let fileURL = storageDirectory
            .appendingPathComponent(course.id.uuidString)
            .appendingPathExtension("json")
        try data.write(to: fileURL)
    }

    func loadAll() -> [UserCourse] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return urls.compactMap { url -> UserCourse? in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let course = try? JSONDecoder().decode(UserCourse.self, from: data)
            else { return nil }
            return course
        }
        .sorted { $0.createdDate > $1.createdDate }
    }

    func delete(_ course: UserCourse) throws {
        let fileURL = storageDirectory
            .appendingPathComponent(course.id.uuidString)
            .appendingPathExtension("json")
        try FileManager.default.removeItem(at: fileURL)
    }
}
