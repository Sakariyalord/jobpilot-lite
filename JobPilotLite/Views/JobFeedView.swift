import SwiftUI

struct JobFeedView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    @State private var locationQuery = ""
    @State private var selectedFilter: JobFeedFilter = .all
    @State private var filteredMatchIDs: [UUID] = []
    @State private var visibleCount = pageSize
    @State private var feedUpdateTask: Task<Void, Never>?
    @State private var searchExpansionTask: Task<Void, Never>?
    @State private var lastSearchExpansionSignature = ""
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
                            hasActiveSearch ? store.t("No search results") : store.t("No Matches Yet"),
                            systemImage: "briefcase",
                            description: Text(hasActiveSearch ? store.t("Try a broader title, skill, company, or location.") : store.t("Complete your profile to see matched roles."))
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
                expandSearchCoverageIfNeeded(debounce: false)
            }
            .onReceive(store.$matchedJobs) { matches in
                refreshFeed(from: matches, applications: store.applicationByJobID, debounce: false)
            }
            .onReceive(store.$applicationByJobID) { applications in
                refreshFeed(from: store.matchedJobs, applications: applications, debounce: false)
            }
            .onChange(of: query) { _, _ in
                refreshFeed(from: store.matchedJobs, applications: store.applicationByJobID, debounce: true)
                expandSearchCoverageIfNeeded(debounce: true)
            }
            .onChange(of: locationQuery) { _, _ in
                refreshFeed(from: store.matchedJobs, applications: store.applicationByJobID, debounce: true)
                expandSearchCoverageIfNeeded(debounce: true)
            }
            .onChange(of: selectedFilter) { _, _ in
                refreshFeed(from: store.matchedJobs, applications: store.applicationByJobID, debounce: false)
                expandSearchCoverageIfNeeded(debounce: false)
            }
            .onDisappear {
                feedUpdateTask?.cancel()
                searchExpansionTask?.cancel()
            }
        }
    }

    private var hasActiveSearch: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedFilter != .all
    }

    private func refreshFeed(
        from matches: [JobMatch],
        applications: [UUID: Application],
        debounce: Bool
    ) {
        let request = JobFeedSearchRequest(query: query, location: locationQuery)
        let filter = selectedFilter

        feedUpdateTask?.cancel()
        feedUpdateTask = Task.detached(priority: .userInitiated) { [matches, applications, request, filter] in
            if debounce {
                try? await Task.sleep(nanoseconds: 180_000_000)
            }

            guard !Task.isCancelled else { return }
            let filteredIDs: [UUID]
            let hasSearch = request.hasSearch

            if !hasSearch && filter == .all {
                filteredIDs = matches.map(\.id)
            } else if filter == .today {
                var candidates: [UUID] = []
                candidates.reserveCapacity(10)
                for match in matches {
                    if Task.isCancelled { return }
                    if hasSearch {
                        guard Self.searchScore(for: match, request: request) > 0 else { continue }
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
                    let score = Self.searchScore(for: match, request: request)
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

    private func expandSearchCoverageIfNeeded(debounce: Bool) {
        let signature = [
            query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            selectedFilter.rawValue
        ].joined(separator: "|")
        guard signature != lastSearchExpansionSignature else { return }
        lastSearchExpansionSignature = signature

        searchExpansionTask?.cancel()
        searchExpansionTask = Task { [query, locationQuery, selectedFilter] in
            if debounce {
                try? await Task.sleep(nanoseconds: 450_000_000)
            }
            guard !Task.isCancelled else { return }
            await store.expandSearchCoverage(query: query, location: locationQuery, filter: selectedFilter.rawValue)
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

    nonisolated fileprivate static func expandSearchText(_ value: String) -> String {
        var output = value.lowercased()
        let replacements: [(String, String)] = [
            ("数据分析师", " data analyst analytics sql dashboard "),
            ("商业分析", " business analyst analytics reporting "),
            ("数据科学家", " data scientist machine learning ml statistics "),
            ("机器学习", " machine learning ml ai model "),
            ("人工智能", " ai machine learning model "),
            ("软件工程师", " software engineer developer backend frontend full stack "),
            ("后端", " backend "),
            ("前端", " frontend "),
            ("全栈", " full stack "),
            ("产品经理", " product manager "),
            ("项目经理", " project manager program manager operations "),
            ("运营", " operations coordinator logistics supply chain "),
            ("物流", " logistics supply chain warehouse operations "),
            ("市场", " marketing content growth brand campaign "),
            ("销售", " sales account executive business development revenue "),
            ("客服", " customer support customer service helpdesk "),
            ("客户成功", " customer success "),
            ("人力资源", " human resources hr recruiting talent "),
            ("招聘", " recruiting recruiter talent acquisition "),
            ("会计", " accounting accountant finance tax audit "),
            ("财务", " finance accounting fp&a payroll "),
            ("护士", " nurse nursing healthcare patient "),
            ("医疗", " healthcare clinical patient "),
            ("教师", " teacher education curriculum tutor instructor "),
            ("行政", " administrative assistant coordinator office manager "),
            ("实习", " intern internship student graduate new grad "),
            ("应届", " entry junior new grad graduate "),
            ("初级", " entry junior associate assistant coordinator "),
            ("高级", " senior staff principal lead "),
            ("全职", " full time "),
            ("兼职", " part time "),
            ("合同", " contract temporary freelance "),
            ("远程", " remote "),
            ("混合", " hybrid "),
            ("线下", " on site office "),
            ("现场", " on site onsite field office "),
            ("签证", " visa sponsorship h1b opt cpt work authorization "),
            ("工签", " visa sponsorship work permit authorization "),
            ("纽约", " new york "),
            ("伦敦", " london "),
            ("多伦多", " toronto "),
            ("旧金山", " san francisco "),
            ("洛杉矶", " los angeles "),
            ("西雅图", " seattle "),
            ("波士顿", " boston "),
            ("温哥华", " vancouver "),
            ("悉尼", " sydney "),
            ("墨尔本", " melbourne "),
            ("德国", " germany berlin munich "),
            ("法国", " france paris "),
            ("英国", " united kingdom uk london "),
            ("加拿大", " canada toronto vancouver "),
            ("澳洲", " australia sydney melbourne "),
            ("美国", " united states usa us ")
        ]

        for (source, replacement) in replacements {
            output = output.replacingOccurrences(of: source, with: replacement)
        }

        return output
    }

    nonisolated private static func searchScore(for match: JobMatch, request: JobFeedSearchRequest) -> Int {
        let document = JobSearchDocument(match: match)
        guard request.matchesHardConstraints(document) else { return 0 }

        var score = request.phraseScore(in: document)
        var missingTerms = 0

        for term in request.terms {
            let termScore = scoreTerm(term, in: document)
            if termScore == 0 {
                missingTerms += 1
            } else {
                score += termScore
            }
        }

        for term in request.locationTerms {
            let termScore = scoreLocationTerm(term, in: document)
            if termScore == 0 {
                return 0
            }
            score += termScore
        }

        let allowedMisses = request.terms.count >= 5 ? 1 : 0
        guard missingTerms <= allowedMisses else { return 0 }

        score += min(match.score / 3, 30)
        if match.job.postedDate > Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast {
            score += 8
        }
        return score
    }

    nonisolated private static func scoreTerm(_ term: String, in document: JobSearchDocument) -> Int {
        let variants = variants(for: term)
        if variants.contains(where: { document.title.contains($0) }) { return 120 }
        if variants.contains(where: { document.titleTokens.contains($0) }) { return 105 }
        if variants.contains(where: { document.company.contains($0) }) { return 95 }
        if variants.contains(where: { document.tags.contains($0) }) { return 70 }
        if variants.contains(where: { document.category.contains($0) }) { return 65 }
        if variants.contains(where: { document.city.contains($0) || document.remoteType.contains($0) }) { return 50 }
        if variants.contains(where: { document.body.contains($0) }) { return 30 }
        if variants.contains(where: { document.hasPrefixMatch(for: $0) }) { return 24 }
        return 0
    }

    nonisolated private static func scoreLocationTerm(_ term: String, in document: JobSearchDocument) -> Int {
        let variants = variants(for: term)
        if variants.contains(where: { document.city.contains($0) }) { return 105 }
        if variants.contains(where: { document.remoteType.contains($0) }) { return 90 }
        if variants.contains(where: { document.body.contains($0) }) { return 24 }
        return 0
    }

    nonisolated fileprivate static func variants(for term: String) -> Set<String> {
        switch term {
        case "developer":
            return ["developer", "software", "engineer", "programmer"]
        case "engineer":
            return ["engineer", "engineering", "developer"]
        case "software":
            return ["software", "developer", "backend", "frontend", "fullstack", "full-stack", "engineering", "platform"]
        case "backend":
            return ["backend", "back-end", "server", "api", "platform"]
        case "frontend":
            return ["frontend", "front-end", "react", "web", "ui"]
        case "fullstack":
            return ["fullstack", "full-stack", "full stack", "frontend", "backend"]
        case "data":
            return ["data", "analytics", "analyst", "scientist", "sql", "bi", "insights", "reporting"]
        case "analyst":
            return ["analyst", "analytics", "analysis", "business intelligence"]
        case "scientist":
            return ["scientist", "science", "machine learning", "ml", "research"]
        case "machine", "ml":
            return ["machine learning", "ml", "ai", "model", "research"]
        case "ai":
            return ["ai", "artificial intelligence", "machine learning", "ml", "llm"]
        case "product":
            return ["product", "pm"]
        case "manager":
            return ["manager", "management", "lead", "program manager", "project manager"]
        case "remote":
            return ["remote", "distributed", "work from home"]
        case "hybrid":
            return ["hybrid"]
        case "onsite":
            return ["on-site", "onsite", "office", "field"]
        case "intern":
            return ["intern", "internship", "student", "graduate"]
        case "entry":
            return ["entry", "junior", "associate", "assistant", "coordinator", "new grad", "graduate"]
        case "senior":
            return ["senior", "staff", "principal", "lead", "director"]
        case "nurse":
            return ["nurse", "nursing", "rn", "clinical", "patient"]
        case "healthcare":
            return ["healthcare", "clinical", "patient", "medical"]
        case "finance":
            return ["finance", "accounting", "fp&a", "payroll", "tax", "treasury"]
        case "accounting":
            return ["accounting", "accountant", "audit", "tax", "bookkeeping"]
        case "operations":
            return ["operations", "logistics", "supply chain", "coordinator", "warehouse", "program manager"]
        case "marketing":
            return ["marketing", "content", "campaign", "brand", "growth", "seo"]
        case "sales":
            return ["sales", "account executive", "business development", "pipeline", "revenue"]
        case "support":
            return ["support", "customer support", "helpdesk", "service"]
        case "success":
            return ["success", "customer success", "client success", "implementation"]
        case "hr":
            return ["hr", "human resources", "recruiting", "talent", "people operations"]
        case "visa":
            return ["visa", "sponsorship", "h-1b", "h1b", "opt", "cpt", "work authorization"]
        case "usa", "us":
            return ["united states", "usa", "u.s.", " us ", "remote - united states"]
        case "uk":
            return ["united kingdom", "uk", "london", "england"]
        default:
            return [term]
        }
    }
}

private struct JobFeedSearchRequest: Sendable {
    var terms: [String]
    var locationTerms: [String]
    var phrases: [String]
    var excludedTerms: [String]
    var workModes: Set<String>
    var opportunities: Set<String>
    var seniority: Set<String>
    var minimumSalary: Int?
    var requiresVisaFriendly: Bool
    var requiresContact: Bool
    var requiresSalary: Bool

    init(query: String, location: String) {
        let expandedQuery = JobFeedView.expandSearchText(query)
        let expandedLocation = JobFeedView.expandSearchText(location)
        let raw = "\(query) \(location)".lowercased()
        let allTokens = Self.tokens(from: expandedQuery)
        let locationTokens = Self.tokens(from: expandedLocation)
        let excluded = Self.excludedTerms(from: raw)
        let stopWords: Set<String> = [
            "job", "jobs", "role", "roles", "position", "positions", "opening", "openings",
            "hiring", "hire", "for", "with", "and", "the", "near", "in", "at", "of", "a",
            "an", "to", "me", "find", "looking", "level"
        ]

        self.locationTerms = locationTokens.filter { !stopWords.contains($0) && !excluded.contains($0) }
        self.phrases = Self.phrases(from: expandedQuery)
        self.excludedTerms = Array(excluded)
        self.workModes = Self.workModes(from: raw, tokens: Set(allTokens + locationTokens))
        self.opportunities = Self.opportunities(from: raw, tokens: Set(allTokens + locationTokens))
        self.seniority = Self.seniority(from: raw, tokens: Set(allTokens))
        self.minimumSalary = Self.minimumSalary(from: raw)
        self.requiresVisaFriendly = raw.contains("visa") || raw.contains("sponsor") || raw.contains("h1b") || raw.contains("opt") || raw.contains("工签") || raw.contains("签证")
        self.requiresContact = raw.contains("contact") || raw.contains("recruiter") || raw.contains("email") || raw.contains("招聘邮箱")
        self.requiresSalary = raw.range(of: #"\b(salary|pay|compensation)\b"#, options: .regularExpression) != nil || raw.contains("薪资") || raw.contains("工资")

        let structuralTerms = workModes
            .union(opportunities)
            .union(seniority)
            .union([
                "remote", "hybrid", "onsite", "on", "site", "office", "full", "time", "part",
                "contract", "temporary", "freelance", "intern", "internship", "student", "graduate",
                "entry", "junior", "associate", "assistant", "coordinator", "new", "grad", "level",
                "senior", "staff", "principal", "lead", "director", "visa", "sponsor", "sponsorship",
                "h1b", "opt", "cpt", "salary", "pay", "compensation", "contact", "recruiter", "email"
            ])
        self.terms = allTokens
            .filter { !stopWords.contains($0) && !excluded.contains($0) && !structuralTerms.contains($0) }
            .stableUnique()
    }

    var hasSearch: Bool {
        !terms.isEmpty ||
        !locationTerms.isEmpty ||
        !phrases.isEmpty ||
        !excludedTerms.isEmpty ||
        !workModes.isEmpty ||
        !opportunities.isEmpty ||
        !seniority.isEmpty ||
        minimumSalary != nil ||
        requiresVisaFriendly ||
        requiresContact ||
        requiresSalary
    }

    func matchesHardConstraints(_ document: JobSearchDocument) -> Bool {
        for term in excludedTerms where JobFeedView.variants(for: term).contains(where: { document.anyText.contains($0) }) {
            return false
        }

        if !workModes.isEmpty && workModes.isDisjoint(with: document.workModes) { return false }
        if !opportunities.isEmpty && opportunities.isDisjoint(with: document.opportunities) { return false }
        if !seniority.isEmpty && seniority.isDisjoint(with: document.seniority) { return false }
        if let minimumSalary, (document.salaryHigh ?? 0) < minimumSalary { return false }
        if requiresVisaFriendly && !document.visaFriendly { return false }
        if requiresContact && !document.hasContact { return false }
        if requiresSalary && document.salaryHigh == nil { return false }
        return true
    }

    func phraseScore(in document: JobSearchDocument) -> Int {
        var score = 0
        for phrase in phrases {
            if document.title.contains(phrase) {
                score += 170
            } else if document.company.contains(phrase) {
                score += 140
            } else if document.tags.contains(phrase) {
                score += 110
            } else if document.anyText.contains(phrase) {
                score += 70
            }
        }
        return score
    }

    private static func tokens(from value: String) -> [String] {
        value
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.count >= 2 }
    }

    private static func phrases(from value: String) -> [String] {
        let normalized = value.lowercased()
        let known = [
            "data analyst", "business analyst", "data scientist", "software engineer", "product manager",
            "project manager", "program manager", "account executive", "customer success", "customer support",
            "machine learning", "marketing manager", "financial analyst", "operations coordinator",
            "human resources", "talent acquisition", "full stack", "new grad"
        ]
        return known.filter { normalized.contains($0) }
    }

    private static func excludedTerms(from value: String) -> Set<String> {
        var terms = Set<String>()
        let tokens = value.split(separator: " ").map(String.init)
        for (index, token) in tokens.enumerated() {
            if token.hasPrefix("-") {
                let cleaned = token.dropFirst().lowercased().filter { $0.isLetter || $0.isNumber }
                if !cleaned.isEmpty { terms.insert(String(cleaned)) }
            }
            if ["no", "not", "without", "exclude", "不是", "不要", "排除"].contains(token.lowercased()), index + 1 < tokens.count {
                let cleaned = tokens[index + 1].lowercased().filter { $0.isLetter || $0.isNumber }
                if !cleaned.isEmpty { terms.insert(String(cleaned)) }
            }
        }
        return terms
    }

    private static func workModes(from raw: String, tokens: Set<String>) -> Set<String> {
        var values = Set<String>()
        if tokens.contains("remote") || raw.contains("远程") { values.insert("remote") }
        if tokens.contains("hybrid") || raw.contains("混合") { values.insert("hybrid") }
        if tokens.contains("onsite") || raw.contains("on site") || raw.contains("on-site") || raw.contains("线下") || raw.contains("现场") { values.insert("on-site") }
        return values
    }

    private static func opportunities(from raw: String, tokens: Set<String>) -> Set<String> {
        var values = Set<String>()
        if tokens.contains("intern") || tokens.contains("internship") || raw.contains("实习") { values.insert("internship") }
        if raw.contains("full time") || raw.contains("full-time") || raw.contains("全职") { values.insert("full-time") }
        if tokens.contains("contract") || raw.contains("part time") || raw.contains("part-time") || raw.contains("兼职") || raw.contains("合同") { values.insert("contract") }
        return values
    }

    private static func seniority(from raw: String, tokens: Set<String>) -> Set<String> {
        var values = Set<String>()
        if tokens.contains("intern") || tokens.contains("internship") || raw.contains("实习") { values.insert("intern") }
        if tokens.contains("entry") || tokens.contains("junior") || raw.contains("new grad") || raw.contains("应届") || raw.contains("初级") { values.insert("entry") }
        if tokens.contains("senior") || tokens.contains("staff") || tokens.contains("principal") || raw.contains("高级") { values.insert("senior") }
        return values
    }

    private static func minimumSalary(from raw: String) -> Int? {
        guard raw.contains("$") ||
                raw.contains("usd") ||
                raw.range(of: #"\b(salary|pay|compensation)\b"#, options: .regularExpression) != nil ||
                raw.range(of: #"\d+\s?k\b"#, options: .regularExpression) != nil ||
                raw.range(of: #"\d+\s?(千|万)"#, options: .regularExpression) != nil ||
                raw.contains("薪资") ||
                raw.contains("工资") ||
                raw.contains("年薪") else {
            return nil
        }
        let normalized = raw.replacingOccurrences(of: ",", with: "")
        let pattern = #"(?:\$|usd\s*)?(\d{2,6})(?:\s?k|\s?千|\s?万)?\+?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.matches(in: normalized, range: NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)).last,
              let numberRange = Range(match.range(at: 1), in: normalized),
              let number = Int(normalized[numberRange]) else {
            return nil
        }
        if normalized.contains("万") { return number * 10_000 }
        if normalized.contains("k") || number < 1000 { return number * 1000 }
        return number
    }
}

private struct JobSearchDocument: Sendable {
    var title: String
    var company: String
    var city: String
    var remoteType: String
    var salary: String
    var tags: String
    var category: String
    var body: String
    var anyText: String
    var titleTokens: Set<String>
    var allTokens: Set<String>
    var workModes: Set<String>
    var opportunities: Set<String>
    var seniority: Set<String>
    var salaryHigh: Int?
    var visaFriendly: Bool
    var hasContact: Bool

    init(match: JobMatch) {
        title = match.job.title.lowercased()
        company = match.job.company.lowercased()
        city = match.job.city.lowercased()
        remoteType = match.job.remoteType.lowercased()
        salary = match.job.salary.lowercased()
        tags = match.job.tags.joined(separator: " ").lowercased()
        category = match.job.tags.first?.lowercased() ?? ""
        body = [match.job.summary, match.job.requirements.joined(separator: " ")].joined(separator: " ").lowercased()
        anyText = [title, company, city, remoteType, salary, tags, body].joined(separator: " ")
        titleTokens = Set(Self.tokens(title))
        allTokens = Set(Self.tokens(anyText))
        workModes = Self.detectWorkModes(remoteType: remoteType, city: city, body: body)
        opportunities = Self.detectOpportunities(anyText)
        seniority = Self.detectSeniority(title)
        salaryHigh = Self.salaryHigh(from: salary)
        visaFriendly = match.job.visaFriendly
        hasContact = match.job.contactEmail != nil
    }

    func hasPrefixMatch(for term: String) -> Bool {
        guard term.count >= 4 else { return false }
        return allTokens.contains { token in token.hasPrefix(term) || term.hasPrefix(token) && token.count >= 4 }
    }

    private static func tokens(_ value: String) -> [String] {
        value
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.count >= 2 }
    }

    private static func detectWorkModes(remoteType: String, city: String, body: String) -> Set<String> {
        let text = "\(remoteType) \(city) \(body)"
        var modes = Set<String>()
        if text.contains("remote") || text.contains("distributed") { modes.insert("remote") }
        if text.contains("hybrid") { modes.insert("hybrid") }
        if text.contains("on-site") || text.contains("onsite") || text.contains("office") { modes.insert("on-site") }
        return modes.isEmpty ? ["any"] : modes
    }

    private static func detectOpportunities(_ text: String) -> Set<String> {
        if text.range(of: #"\b(intern|internship|co-?op|student|new grad|graduate)\b"#, options: .regularExpression) != nil {
            return ["internship"]
        }
        if text.range(of: #"\b(contract|temporary|part.?time|seasonal|freelance)\b"#, options: .regularExpression) != nil {
            return ["contract"]
        }
        return ["full-time"]
    }

    private static func detectSeniority(_ title: String) -> Set<String> {
        if title.range(of: #"\b(intern|internship)\b"#, options: .regularExpression) != nil { return ["intern"] }
        if title.range(of: #"\b(entry|junior|associate|assistant|coordinator|new grad|graduate)\b"#, options: .regularExpression) != nil { return ["entry"] }
        if title.range(of: #"\b(senior|staff|principal|lead|director|head|vp)\b"#, options: .regularExpression) != nil { return ["senior"] }
        return ["mid"]
    }

    private static func salaryHigh(from salary: String) -> Int? {
        guard !salary.localizedCaseInsensitiveContains("not listed") else { return nil }
        let normalized = salary.replacingOccurrences(of: ",", with: "")
        guard let regex = try? NSRegularExpression(pattern: #"(\d{2,6})(?:\.\d+)?\s?k?"#, options: [.caseInsensitive]) else { return nil }
        let matches = regex.matches(in: normalized, range: NSRange(normalized.startIndex..<normalized.endIndex, in: normalized))
        let values = matches.compactMap { match -> Int? in
            guard let range = Range(match.range(at: 1), in: normalized),
                  let raw = Int(normalized[range]) else { return nil }
            return raw < 1000 ? raw * 1000 : raw
        }
        return values.max()
    }
}

private extension Array where Element: Hashable {
    func stableUnique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
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
        SearchSuggestion(title: "Finance Analyst", systemImage: "banknote", target: .query),
        SearchSuggestion(title: "Marketing", systemImage: "megaphone", target: .query),
        SearchSuggestion(title: "Operations", systemImage: "shippingbox", target: .query),
        SearchSuggestion(title: "Internship", systemImage: "graduationcap", target: .query),
        SearchSuggestion(title: "Entry Level", systemImage: "figure.stairs", target: .query),
        SearchSuggestion(title: "Healthcare", systemImage: "cross.case", target: .query),
        SearchSuggestion(title: "Visa Sponsorship", systemImage: "doc.badge.gearshape", target: .query),
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
    case hybrid = "Hybrid"
    case onsite = "On-site"
    case internship = "Internship"
    case fullTime = "Full-time"
    case entry = "Entry"
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
        case .hybrid:
            return match.job.remoteType.localizedCaseInsensitiveContains("hybrid") ||
            searchText(for: match).contains(" hybrid ")
        case .onsite:
            let text = searchText(for: match)
            return match.job.remoteType.localizedCaseInsensitiveContains("on-site") ||
            match.job.remoteType.localizedCaseInsensitiveContains("onsite") ||
            text.contains(" onsite ") ||
            text.contains(" on-site ") ||
            text.contains(" office ")
        case .internship:
            return searchText(for: match).range(
                of: #"\b(intern|internship|co-?op|student|graduate)\b"#,
                options: .regularExpression
            ) != nil
        case .fullTime:
            let text = searchText(for: match)
            return text.range(of: #"\b(intern|internship|contract|temporary|part.?time|seasonal|freelance)\b"#, options: .regularExpression) == nil
        case .entry:
            return searchText(for: match).range(
                of: #"\b(entry|junior|associate|assistant|coordinator|new grad|graduate|intern|internship)\b"#,
                options: .regularExpression
            ) != nil
        case .visa:
            return match.job.visaFriendly
        case .salary:
            return match.job.salary != "Not listed"
        case .contact:
            return match.job.contactEmail != nil
        }
    }

    private func searchText(for match: JobMatch) -> String {
        [
            match.job.title,
            match.job.company,
            match.job.city,
            match.job.remoteType,
            match.job.salary,
            match.job.tags.joined(separator: " "),
            match.job.summary,
            match.job.requirements.joined(separator: " ")
        ]
        .joined(separator: " ")
        .lowercased()
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
