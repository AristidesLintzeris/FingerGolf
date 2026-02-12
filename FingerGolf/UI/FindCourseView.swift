import SwiftUI

struct FindCourseView: View {

    @ObservedObject var cloudKitManager: CloudKitManager
    var onSelectCourse: (UserCourse) -> Void
    var onBack: () -> Void

    @State private var sortOrder: CommunitySortOrder = .newest
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .bodyStyle(size: 22)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Text("FIND COURSE")
                    .headingStyle(size: 28)

                Spacer()

                // Surprise me button
                Button {
                    Task {
                        if let course = await cloudKitManager.fetchRandomCourse() {
                            onSelectCourse(course)
                        }
                    }
                } label: {
                    Image(systemName: "dice.fill")
                        .bodyStyle(size: 20)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.5))
                TextField("Search courses...", text: $searchText)
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        Task {
                            if searchText.isEmpty {
                                await cloudKitManager.fetchCommunityCourses(sortBy: sortOrder)
                            } else {
                                await cloudKitManager.searchCourses(query: searchText)
                            }
                        }
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Task {
                            await cloudKitManager.fetchCommunityCourses(sortBy: sortOrder)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // Sort options
            Picker("Sort", selection: $sortOrder) {
                Text("NEWEST").tag(CommunitySortOrder.newest)
                Text("POPULAR").tag(CommunitySortOrder.popular)
                Text("BEST AVG").tag(CommunitySortOrder.bestAverage)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .onChange(of: sortOrder) { _, newValue in
                Task {
                    await cloudKitManager.fetchCommunityCourses(sortBy: newValue)
                }
            }

            // Surprise Me button
            Button {
                Task {
                    if let course = await cloudKitManager.fetchRandomCourse() {
                        onSelectCourse(course)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shuffle")
                    Text("SURPRISE ME")
                }
                .bodyStyle(size: 14)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.4), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            if cloudKitManager.isLoading {
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            } else if cloudKitManager.communityCourses.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("NO COURSES FOUND")
                        .lightStyle(size: 14)
                    Text("Be the first to publish a course!")
                        .lightStyle(size: 12)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(cloudKitManager.communityCourses) { course in
                            Button {
                                onSelectCourse(course)
                            } label: {
                                communityRow(course)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
        .task {
            await cloudKitManager.fetchCommunityCourses(sortBy: sortOrder)
        }
    }

    private func communityRow(_ course: UserCourse) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(course.definition.name.uppercased())
                    .bodyStyle(size: 16)

                Text("by \(course.authorName)")
                    .lightStyle(size: 12)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("PAR \(course.definition.par)")
                    .bodyStyle(size: 14)

                HStack(spacing: 12) {
                    Label("\(course.playCount)", systemImage: "arrow.down.circle")
                        .lightStyle(size: 11)

                    if course.averageStrokes > 0 {
                        Label(String(format: "%.1f avg", course.averageStrokes),
                              systemImage: "chart.bar.fill")
                            .lightStyle(size: 11)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}
