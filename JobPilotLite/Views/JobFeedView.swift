import SwiftUI

struct JobFeedView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    @State private var locationQuery = ""
    @State private var selectedFilter: JobFeedFilter = .all
    @State private var filteredMatchIDs: [UUID] = []
    @State private var visibleCount = pageSize
    @State private var feedUpdateTask: Task<Void, Never>?
    @State private var navigationPath = NavigationPath()

    private static let pageSize = 24

    private var visibleMatchIDs: ArraySlice<UUID> {
        filteredMatchIDs.prefix(visibleCount)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    SearchToolsCard(query: $query, locationQuery: $locationQuery)
                        .listRowSeparator(.hidden)
                }

                Section {
                    FilterRail(selectedFilter: $selectedFilter)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                if store.isLoadingJobs && filteredMatchIDs.isEmpty {
                    Section {
                        LoadingJobsView()
                            .listRowSeparator(.hidden)
                    }
                } else if store.jobs.isEmpty {
                    Section {
                        ContentUnavailableView(
                            store.t("No verified jobs available"),
                            systemImage: "checkmark.shield",
                            description: Text(store.t("The job feed is waiting for a fresh live verification run."))
                        )
                        .listRowSeparator(.hidden)
                    }
                } else if filteredMatchIDs.isEmpty {
                    Section {
                        ContentUnavailableView(
                            store.t("No Matches Yet"),
                            systemImage: "briefcase",
                            description: Text(store.t("Complete your profile to see matched roles."))
                        )
                        .listRowSeparator(.hidden)
                    }
                } else {
                    Section {
                    ForEach(visibleMatchIDs, id: \.self) { matchID in
                        if let match = store.match(for: matchID) {
                            Button {
                                navigationPath.append(matchID)
                            } label: {
                                HStack(spacing: 8) {
                                    JobRow(snapshot: rowSnapshot(for: match))
                                        .equatable()
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Image(systemName: "chevron.right")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    store.save(job: match.job, status: .saved)
                                } label: {
                                    Label(store.t("Save"), systemImage: "bookmark")
                                }
                                .tint(.blue)
                            }
                            .onAppear {
                                loadMoreIfNeeded(current: matchID)
                            }
                        }
                    }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: store.t("Search any title, company, skill"))
            .navigationTitle(store.t("Matches"))
            .toolbar {
                ToolbarItem(placement: AppToolbarPlacement.trailing) {
                    Button {
                        store.selectedTab = 1
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel(store.t("Edit profile"))
                }
            }
            .navigationDestination(for: UUID.self) { jobID in
                if let match = store.match(for: jobID) {
                    JobDetailView(match: match)
                } else {
                    ContentUnavailableView(
                        store.t("No Matches Yet"),
                        systemImage: "briefcase",
                        description: Text(store.t("Complete your profile to see matched roles."))
                    )
                }
            }
            .onAppear {
                refreshFeed(from: store.matchedJobs, applications: store.applicationByJobID, debounce: false)
            }
            .onReceive(store.$matchedJobs) { matches in
                refreshFeed(from: matches, applications: store.applicationByJobID, debounce: false)
            }
            .onReceive(store.$applicationByJobID) { applications in
                refreshFeed(from: store.matchedJobs, applications: applications, debounce: false)
            }
            .onChange(of: query) { _, _ in
                refreshFeed(from: store.matchedJobs, applications: store.applicationByJobID, debounce: true)
            }
            .onChange(of: locationQuery) { _, _ in
                refreshFeed(from: store.matchedJobs, applications: store.applicationByJobID, debounce: true)
            }
            .onChange(of: selectedFilter) { _, _ in
                refreshFeed(from: store.matchedJobs, applications: store.applicationByJobID, debounce: false)
            }
            .onDisappear {
                feedUpdateTask?.cancel()
            }
        }
    }

    private func refreshFeed(
        from matches: [JobMatch],
        applications: [UUID: Application],
        debounce: Bool
    ) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedLocation = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filter = selectedFilter

        feedUpdateTask?.cancel()
        feedUpdateTask = Task.detached(priority: .userInitiated) { [matches, applications, normalizedQuery, normalizedLocation, filter] in
            if debounce {
                try? await Task.sleep(nanoseconds: 180_000_000)
            }

            guard !Task.isCancelled else { return }
            let filteredIDs: [UUID]
            let queryTerms = Self.searchTerms(from: normalizedQuery)
            let locationTerms = Self.searchTerms(from: normalizedLocation)
            let hasSearch = !queryTerms.isEmpty || !locationTerms.isEmpty

            if !hasSearch && filter == .all {
                filteredIDs = matches.map(\.id)
            } else if filter == .today {
                var candidates: [UUID] = []
                candidates.reserveCapacity(10)
                for match in matches {
                    if Task.isCancelled { return }
                    if hasSearch {
                        guard Self.searchScore(for: match, queryTerms: queryTerms, locationTerms: locationTerms) > 0 else { continue }
                    }
                    if let application = applications[match.job.id],
                       [.applied, .followUp, .interview, .rejected, .offer].contains(application.status) {
                        continue
                    }
                    if match.score >= 80 || candidates.count < 10 {
                        candidates.append(match.id)
                    }
                    if candidates.count >= 10 { break }
                }
                filteredIDs = candidates
            } else {
                var results: [(id: UUID, searchScore: Int, matchScore: Int, postedDate: Date)] = []
                results.reserveCapacity(min(matches.count, 512))
                for match in matches {
                    if Task.isCancelled { return }
                    guard filter.includes(match) else { continue }
                    let score = Self.searchScore(for: match, queryTerms: queryTerms, locationTerms: locationTerms)
                    guard !hasSearch || score > 0 else { continue }
                    results.append((match.id, score, match.score, match.job.postedDate))
                }
                filteredIDs = results
                    .sorted {
                        if $0.searchScore == $1.searchScore {
                            if $0.matchScore == $1.matchScore {
                                return $0.postedDate > $1.postedDate
                            }
                            return $0.matchScore > $1.matchScore
                        }
                        return $0.searchScore > $1.searchScore
                    }
                    .map(\.id)
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                filteredMatchIDs = filteredIDs
                visibleCount = min(Self.pageSize, filteredIDs.count)
            }
        }
    }

    private func loadMoreIfNeeded(current matchID: UUID) {
        let lastVisibleIndex = min(visibleCount, filteredMatchIDs.count) - 1
        guard lastVisibleIndex >= 0, matchID == filteredMatchIDs[lastVisibleIndex] else { return }
        guard visibleCount < filteredMatchIDs.count else { return }
        visibleCount = min(visibleCount + Self.pageSize, filteredMatchIDs.count)
    }

    private func rowSnapshot(for match: JobMatch) -> JobRowSnapshot {
        let isSaved = store.application(for: match.job) != nil
        return JobRowSnapshot(
            title: store.localizedJobTitle(match.job.title),
            company: store.localizedCompany(match.job.company),
            score: "\(match.score)",
            label: store.t(match.label),
            city: store.localizedJobCity(match.job.city),
            remoteType: store.localizedRemoteType(match.job.remoteType),
            salary: store.localizedSalary(match.job.salary),
            contact: match.job.contactEmail == nil ? store.t("Apply link") : store.t("Contact"),
            contactSystemImage: match.job.contactEmail == nil ? "link" : "envelope",
            saved: isSaved ? store.t("Saved") : nil,
            tags: store.displayTags(for: match.job).prefix(4).map(store.localizedJobTag)
        )
    }

    nonisolated private static func searchTerms(from value: String) -> [String] {
        let expanded = expandSearchText(value)
        let stopWords: Set<String> = ["job", "jobs", "role", "roles", "position", "positions", "openings", "hiring", "for", "with", "and", "the", "near", "in", "at"]

        return expanded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.count >= 2 && !stopWords.contains($0) }
    }

    nonisolated private static func expandSearchText(_ value: String) -> String {
        var output = value.lowercased()
        let replacements: [(String, String)] = [
            ("数据分析师", " data analyst "),
            ("数据科学家", " data scientist "),
            ("软件工程师", " software engineer "),
            ("后端", " backend "),
            ("前端", " frontend "),
            ("全栈", " full stack "),
            ("产品经理", " product manager "),
            ("运营", " operations "),
            ("市场", " marketing "),
            ("销售", " sales "),
            ("客服", " customer support "),
            ("客户成功", " customer success "),
            ("护士", " nurse nursing healthcare patient "),
            ("医疗", " healthcare clinical patient "),
            ("实习", " intern internship "),
            ("全职", " full time "),
            ("兼职", " part time "),
            ("远程", " remote "),
            ("混合", " hybrid "),
            ("线下", " on site office "),
            ("纽约", " new york "),
            ("伦敦", " london "),
            ("多伦多", " toronto "),
            ("旧金山", " san francisco "),
            ("洛杉矶", " los angeles ")
        ]

        for (source, replacement) in replacements {
            output = output.replacingOccurrences(of: source, with: replacement)
        }

        return output
    }

    nonisolated private static func searchScore(for match: JobMatch, queryTerms: [String], locationTerms: [String]) -> Int {
        let title = match.job.title.lowercased()
        let company = match.job.company.lowercased()
        let city = match.job.city.lowercased()
        let remote = match.job.remoteType.lowercased()
        let tags = match.job.tags.joined(separator: " ").lowercased()
        let body = [match.job.summary, match.job.requirements.joined(separator: " ")].joined(separator: " ").lowercased()

        var score = 0
        var missingQueryTerms = 0

        for term in queryTerms {
            let variants = variants(for: term)
            if variants.contains(where: { title.contains($0) }) {
                score += 90
            } else if variants.contains(where: { company.contains($0) }) {
                score += 70
            } else if variants.contains(where: { tags.contains($0) }) {
                score += 50
            } else if variants.contains(where: { body.contains($0) }) {
                score += 25
            } else if variants.contains(where: { city.contains($0) || remote.contains($0) }) {
                score += 20
            } else {
                missingQueryTerms += 1
            }
        }

        for term in locationTerms {
            let variants = variants(for: term)
            if variants.contains(where: { city.contains($0) }) {
                score += 85
            } else if variants.contains(where: { remote.contains($0) }) {
                score += 70
            } else if variants.contains(where: { body.contains($0) }) {
                score += 18
            } else {
                return 0
            }
        }

        if queryTerms.isEmpty && !locationTerms.isEmpty {
            return score
        }

        let allowedMisses = queryTerms.count >= 4 ? 1 : 0
        return missingQueryTerms <= allowedMisses ? score : 0
    }

    nonisolated private static func variants(for term: String) -> [String] {
        switch term {
        case "engineer":
            return ["engineer", "engineering"]
        case "software":
            return ["software", "developer", "backend", "frontend", "fullstack", "full-stack"]
        case "data":
            return ["data", "analytics", "analyst", "scientist", "sql"]
        case "analyst":
            return ["analyst", "analytics", "analysis", "business intelligence"]
        case "product":
            return ["product", "pm"]
        case "manager":
            return ["manager", "management", "lead"]
        case "remote":
            return ["remote"]
        case "hybrid":
            return ["hybrid"]
        case "intern":
            return ["intern", "internship", "student", "graduate"]
        case "nurse":
            return ["nurse", "nursing", "rn", "clinical", "patient"]
        case "healthcare":
            return ["healthcare", "clinical", "patient", "medical"]
        case "marketing":
            return ["marketing", "content", "campaign", "brand"]
        case "sales":
            return ["sales", "account executive", "business development", "pipeline", "revenue"]
        case "support":
            return ["support", "customer support", "helpdesk", "service"]
        default:
            return [term]
        }
    }
}

struct SearchToolsCard: View {
    @EnvironmentObject private var store: AppStore
    @Binding var query: String
    @Binding var locationQuery: String

    private let suggestions: [SearchSuggestion] = [
        SearchSuggestion(title: "Data Analyst", systemImage: "chart.bar", target: .query),
        SearchSuggestion(title: "Software Engineer", systemImage: "chevron.left.forwardslash.chevron.right", target: .query),
        SearchSuggestion(title: "Product Manager", systemImage: "rectangle.stack", target: .query),
        SearchSuggestion(title: "Internship", systemImage: "graduationcap", target: .query),
        SearchSuggestion(title: "Healthcare", systemImage: "cross.case", target: .query),
        SearchSuggestion(title: "Remote", systemImage: "desktopcomputer", target: .location)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(store.t("Role, company, or skill"), text: $query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
            }
            .fieldStyle()

            TextField(store.t("Location or remote"), text: $locationQuery)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .fieldStyle()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            switch suggestion.target {
                            case .query:
                                query = suggestion.title
                            case .location:
                                locationQuery = suggestion.title
                            }
                        } label: {
                            Label(store.t(suggestion.title), systemImage: suggestion.systemImage)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                        .background(AppColor.secondaryGroupedBackground)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SearchSuggestion: Identifiable {
    enum Target {
        case query
        case location
    }

    var id: String { "\(target)-\(title)" }
    var title: String
    var systemImage: String
    var target: Target
}

struct LoadingJobsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(store.t("Loading verified jobs"))
                .font(.headline)
            Text(store.t("Preparing live roles and resume matches."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

enum JobFeedFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case today = "Today"
    case strong = "Strong"
    case remote = "Remote"
    case visa = "Visa"
    case salary = "Salary"
    case contact = "Contact"

    var id: String { rawValue }

    func includes(_ match: JobMatch) -> Bool {
        switch self {
        case .today:
            return true
        case .all:
            return true
        case .strong:
            return match.score >= 80
        case .remote:
            return match.job.remoteType.localizedCaseInsensitiveContains("remote")
        case .visa:
            return match.job.visaFriendly
        case .salary:
            return match.job.salary != "Not listed"
        case .contact:
            return match.job.contactEmail != nil
        }
    }
}

struct FilterRail: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedFilter: JobFeedFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(JobFeedFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(store.t(filter.rawValue))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? Color.blue : AppColor.secondaryGroupedBackground)
                            .foregroundStyle(selectedFilter == filter ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.trailing, 16)
        }
    }
}

private struct JobRowSnapshot: Equatable {
    var title: String
    var company: String
    var score: String
    var label: String
    var city: String
    var remoteType: String
    var salary: String
    var contact: String
    var contactSystemImage: String
    var saved: String?
    var tags: [String]
}

private struct JobRow: View, Equatable {
    var snapshot: JobRowSnapshot

    static func == (lhs: JobRow, rhs: JobRow) -> Bool {
        lhs.snapshot == rhs.snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(snapshot.company)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(snapshot.score)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text(snapshot.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    JobMetaLabel(text: snapshot.city, systemImage: "mappin.and.ellipse")
                    JobMetaLabel(text: snapshot.remoteType, systemImage: "desktopcomputer")
                }

                HStack(spacing: 12) {
                    JobMetaLabel(text: snapshot.salary, systemImage: "dollarsign.circle")
                    JobMetaLabel(text: snapshot.contact, systemImage: snapshot.contactSystemImage)
                    if let saved = snapshot.saved {
                        JobMetaLabel(text: saved, systemImage: "bookmark.fill")
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(Array(snapshot.tags.enumerated()), id: \.offset) { _, tag in
                    Text(tag)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.10))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct JobMetaLabel: View {
    var text: String
    var systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
