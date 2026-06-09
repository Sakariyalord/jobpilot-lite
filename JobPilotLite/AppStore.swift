import Foundation

private struct WeightedTerm: Sendable {
    var term: String
    var weight: Int
}

private struct ResumeSignal: Sendable {
    var skills: Set<String>
    var weightedKeywords: [WeightedTerm]
    var categories: Set<String>
    var requirementTerms: Set<String>
}

private struct FeedbackSignal: Sendable {
    var tooSenior: Bool
    var unwantedLocations: Set<String>
    var unwantedIndustries: Set<String>
}

private struct TranslationRule: @unchecked Sendable {
    let regex: NSRegularExpression
    let replacement: String
}

@MainActor
final class AppStore: ObservableObject {
    @Published var profile = CandidateProfile() {
        didSet {
            scheduleMatchRebuild(debounce: true)
        }
    }

    @Published var jobs: [Job] = [] {
        didSet {
            rebuildJobIndex()
            scheduleMatchRebuild(debounce: false)
        }
    }

    @Published private(set) var matchedJobs: [JobMatch] = []
    @Published private(set) var isLoadingJobs = true
    @Published var applications: [Application] = []
    @Published private(set) var applicationByJobID: [UUID: Application] = [:]
    @Published private(set) var feedbackByJobID: [UUID: JobFeedback] = [:]
    @Published private(set) var resumeVersions: [ResumeVersion] = []
    @Published var selectedResumeVersionID: UUID?
    @Published private(set) var analyticsCounters = AnalyticsCounters()
    @Published var settings = AppSettings() {
        didSet {
            clearLocalizationCaches()
            persistSettings()
        }
    }
    @Published var selectedTab = 0

    private let profileKey = "candidate_profile_v1"
    private let applicationsKey = "applications_v1"
    private let feedbackKey = "job_feedback_v1"
    private let resumeVersionsKey = "resume_versions_v1"
    private let analyticsKey = "analytics_events_v1"
    private let settingsKey = "app_settings_v3"
    private let cachedJobsKey = "remote_jobs_cache_v1"
    private let lastJobRefreshKey = "jobs_last_refresh_at_v1"
    private let jobFeedConfig = JobFeedConfig.load()
    private var matchRebuildTask: Task<Void, Never>?
    private var analyticsPersistTask: Task<Void, Never>?
    private var analyticsEvents: [AnalyticsEvent] = []
    private var jobByID: [UUID: Job] = [:]
    private var matchByJobID: [UUID: JobMatch] = [:]
    private var matchGeneration = 0
    private var localizedTitleCache: [String: String] = [:]
    private var localizedCompanyCache: [String: String] = [:]
    private var localizedLocationCache: [String: String] = [:]
    private var localizedRemoteTypeCache: [String: String] = [:]
    private var localizedSalaryCache: [String: String] = [:]
    private var localizedTagCache: [String: String] = [:]
    private var localizedTextCache: [String: String] = [:]
    private var localizedReasonCache: [String: String] = [:]

    init() {
        load()
        rebuildJobIndex()
        rebuildMatchesImmediately()
        Task {
            await loadInitialJobs()
            await refreshJobsIfNeeded()
        }
    }

    var isProfileReady: Bool {
        !profile.fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !profile.email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !profile.targetTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func t(_ key: String) -> String {
        settings.language.localized(key)
    }

    func localizedJobTitle(_ title: String) -> String {
        guard usesChineseInterface else { return title }
        if let cached = localizedTitleCache[title] { return cached }
        let localized = Self.localizeEnglishPhrase(title, replacements: Self.sortedJobPhraseTranslations)
        localizedTitleCache[title] = localized
        trimLocalizationCacheIfNeeded(&localizedTitleCache)
        return localized
    }

    func localizedCompany(_ company: String) -> String {
        guard usesChineseInterface else { return company }
        if let cached = localizedCompanyCache[company] { return cached }
        let localized = Self.companyTranslations[company] ?? company
        localizedCompanyCache[company] = localized
        trimLocalizationCacheIfNeeded(&localizedCompanyCache)
        return localized
    }

    func localizedJobCity(_ city: String) -> String {
        guard usesChineseInterface else { return city }
        if let cached = localizedLocationCache[city] { return cached }
        let localized = Self.localizeEnglishPhrase(city, replacements: Self.sortedLocationTranslations)
        localizedLocationCache[city] = localized
        trimLocalizationCacheIfNeeded(&localizedLocationCache)
        return localized
    }

    func localizedRemoteType(_ remoteType: String) -> String {
        guard usesChineseInterface else { return remoteType }
        if let cached = localizedRemoteTypeCache[remoteType] { return cached }
        let localized = Self.localizeEnglishPhrase(remoteType, replacements: Self.sortedLocationTranslations)
        localizedRemoteTypeCache[remoteType] = localized
        trimLocalizationCacheIfNeeded(&localizedRemoteTypeCache)
        return localized
    }

    func localizedSalary(_ salary: String) -> String {
        guard usesChineseInterface else { return salary }
        if let cached = localizedSalaryCache[salary] { return cached }
        if salary.localizedCaseInsensitiveCompare("Not listed") == .orderedSame {
            let localized = t("Not listed")
            localizedSalaryCache[salary] = localized
            return localized
        }
        let localized = salary
            .replacingOccurrences(of: "/hr", with: "/小时", options: .caseInsensitive)
            .replacingOccurrences(of: "per hour", with: "每小时", options: .caseInsensitive)
            .replacingOccurrences(of: "USD", with: "美元", options: .caseInsensitive)
            .replacingOccurrences(of: "Not listed", with: t("Not listed"), options: .caseInsensitive)
        let formatted = Self.localizeSalaryThousands(localized)
        localizedSalaryCache[salary] = formatted
        trimLocalizationCacheIfNeeded(&localizedSalaryCache)
        return formatted
    }

    func localizedJobTag(_ tag: String) -> String {
        guard usesChineseInterface else { return tag }
        if let cached = localizedTagCache[tag] { return cached }
        let localized = Self.localizeEnglishPhrase(tag, replacements: Self.sortedJobPhraseTranslations)
        localizedTagCache[tag] = localized
        trimLocalizationCacheIfNeeded(&localizedTagCache)
        return localized
    }

    func displayTags(for job: Job) -> [String] {
        Self.normalizedTags(for: job)
    }

    func localizedJobText(_ text: String) -> String {
        guard usesChineseInterface else { return text }
        if let cached = localizedTextCache[text] { return cached }
        let localized = Self.localizeEnglishPhrase(text, replacements: Self.sortedJobTextTranslations)
        localizedTextCache[text] = localized
        trimLocalizationCacheIfNeeded(&localizedTextCache)
        return localized
    }

    func localizedRoleSummary(for job: Job) -> String {
        guard usesChineseInterface else { return job.summary }
        let localized = localizedJobText(job.summary)
        if !isLatinDominant(localized) {
            return localized
        }
        return generatedChineseRoleSummary(for: job)
    }

    func localizedRequirements(for job: Job) -> [String] {
        guard usesChineseInterface else { return job.requirements }
        let localized = job.requirements.map(localizedJobText)
        if localized.isEmpty || localized.contains(where: isLatinDominant) {
            return generatedChineseRequirements(for: job)
        }
        return localized
    }

    func localizedMatchReason(_ reason: String) -> String {
        guard usesChineseInterface else { return reason }
        if let cached = localizedReasonCache[reason] { return cached }

        let localized: String

        if reason.hasPrefix("Skills matched: ") {
            let values = reason.replacingOccurrences(of: "Skills matched: ", with: "")
                .components(separatedBy: ", ")
                .map(localizedJobTag)
                .joined(separator: "、")
            localized = "技能匹配：\(values)"
        } else if reason.hasPrefix("Resume keywords matched: ") {
            let values = reason.replacingOccurrences(of: "Resume keywords matched: ", with: "")
                .components(separatedBy: ", ")
                .map(localizedJobTag)
                .joined(separator: "、")
            localized = "简历关键词匹配：\(values)"
        } else if reason.hasPrefix("Industry fit: ") {
            let values = reason.replacingOccurrences(of: "Industry fit: ", with: "")
                .components(separatedBy: ", ")
                .map(localizedJobTag)
                .joined(separator: "、")
            localized = "行业匹配：\(values)"
        } else if reason.hasPrefix("Adjusted from your feedback: ") {
            let value = reason.replacingOccurrences(of: "Adjusted from your feedback: ", with: "")
            localized = "已根据你的反馈调整：\(t(value))"
        } else {
            let direct: [String: String] = [
                "Title aligns with your target role": "职位名称与你的目标岗位一致",
                "Role requirements overlap with your resume": "岗位要求与你的简历有重叠",
                "Location preference fits": "地点偏好匹配",
                "Target country fits": "目标国家匹配",
                "Remote role still needs hiring-country check": "远程岗位仍需确认雇佣国家限制",
                "Work mode fits": "工作模式匹配",
                "Opportunity type fits": "机会类型匹配",
                "Tagged as visa friendly": "标记为签证友好",
                "No visa constraint set": "未设置签证限制",
                "Work authorization needs clarification": "工作权利还需要写清楚",
                "Sponsorship fit needs checking": "需要先确认雇主是否支持赞助",
                "Work rights look actionable": "工作权利看起来可执行",
                "Experience level looks aligned": "经验级别看起来匹配",
                "Some profile details match this role": "部分资料信息与该职位匹配"
            ]

            localized = direct[reason] ?? localizedJobText(reason)
        }

        localizedReasonCache[reason] = localized
        trimLocalizationCacheIfNeeded(&localizedReasonCache)
        return localized
    }

    func refreshSystemLanguageIfNeeded() {
        guard settings.language == .system else { return }
        clearLocalizationCaches()
        objectWillChange.send()
    }

    private var usesChineseInterface: Bool {
        settings.language == .chinese || (settings.language == .system && AppLanguage.systemPreferred == .chinese)
    }

    private func isLatinDominant(_ text: String) -> Bool {
        let latinCount = text.unicodeScalars.filter { scalar in
            (65...90).contains(Int(scalar.value)) || (97...122).contains(Int(scalar.value))
        }.count
        let hanCount = text.unicodeScalars.filter { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }.count

        return latinCount >= 18 && latinCount > hanCount
    }

    private func generatedChineseRoleSummary(for job: Job) -> String {
        let title = localizedJobTitle(job.title)
        let company = localizedCompany(job.company)
        let searchable = "\(job.title) \(displayTags(for: job).joined(separator: " ")) \(job.summary) \(job.requirements.joined(separator: " "))".lowercased()
        let tagText = displayTags(for: job).prefix(3).map(localizedJobTag).joined(separator: "、")
        let focus = tagText.isEmpty ? "岗位核心能力" : tagText

        if containsAny(["data", "analyst", "analytics", "dashboard", "sql", "research scientist", "data scientist", "machine learning", "applied scientist"], in: searchable) {
            return "\(company) 的 \(title) 聚焦数据分析、指标体系、实验判断和业务决策支持，适合能把数据洞察转化为行动的候选人。"
        }

        if containsAny(["software", "engineer", "developer", "backend", "frontend", "full stack"], in: searchable) {
            return "\(company) 的 \(title) 聚焦产品工程、系统交付、技术实现和稳定性改进，适合能独立推进项目并解释技术取舍的候选人。"
        }

        if containsAny(["sales", "account", "pipeline", "revenue", "business development"], in: searchable) {
            return "\(company) 的 \(title) 聚焦客户开发、销售推进、关系维护和结果达成，适合能清晰沟通并持续推动机会进展的候选人。"
        }

        if containsAny(["customer", "support", "success", "crm", "retention"], in: searchable) {
            return "\(company) 的 \(title) 聚焦客户沟通、问题解决、续约留存和服务质量，适合能稳定处理客户需求并改进流程的候选人。"
        }

        if containsAny(["operations", "logistics", "warehouse", "coordinator", "supply"], in: searchable) {
            return "\(company) 的 \(title) 聚焦流程执行、跨团队协调、效率提升和准确交付，适合能把复杂任务拆解并推进落地的候选人。"
        }

        return "\(company) 的 \(title) 聚焦 \(focus)，需要候选人能结合岗位要求推动日常执行、跨团队协作和可量化结果。"
    }

    private func generatedChineseRequirements(for job: Job) -> [String] {
        let searchable = "\(job.title) \(displayTags(for: job).joined(separator: " ")) \(job.summary) \(job.requirements.joined(separator: " "))".lowercased()

        if containsAny(["data", "analyst", "analytics", "dashboard", "sql", "research scientist", "data scientist", "machine learning", "applied scientist"], in: searchable) {
            return [
                "能使用数据分析、数据库查询或数据看板支持业务判断",
                "能把复杂数据结论转化为清晰建议，并和非技术团队沟通",
                "有指标体系、实验分析、增长分析或业务报告经验者优先",
                "能用可量化成果证明分析对产品、运营或收入的影响"
            ]
        }

        if containsAny(["software", "engineer", "developer", "backend", "frontend", "full stack"], in: searchable) {
            return [
                "有产品工程、后端、前端或全栈项目经验",
                "能说明系统设计、代码质量、性能或可靠性方面的取舍",
                "熟悉版本管理、接口协作、测试和问题排查流程",
                "能和产品、设计或业务团队协作推进上线"
            ]
        }

        if containsAny(["sales", "account", "pipeline", "revenue", "business development"], in: searchable) {
            return [
                "具备客户沟通、机会推进和销售管道管理能力",
                "能处理客户异议，并推动明确的下一步承诺",
                "能用目标、转化、收入或留存数据说明成果",
                "有跨团队协作、客户关系维护或市场拓展经验者优先"
            ]
        }

        if containsAny(["customer", "support", "success", "crm", "retention"], in: searchable) {
            return [
                "具备客户沟通、问题定位和服务恢复能力",
                "能规范记录、升级和关闭客户问题",
                "熟悉客户关系管理、续约留存或满意度提升流程",
                "能用响应效率、解决率或客户反馈证明结果"
            ]
        }

        if containsAny(["operations", "logistics", "warehouse", "coordinator", "supply"], in: searchable) {
            return [
                "具备流程执行、任务协调和异常处理能力",
                "能管理时间节点、优先级和跨团队依赖",
                "能用准确率、吞吐量、成本或效率指标证明成果",
                "有供应链、物流、运营或项目协调经验者优先"
            ]
        }

        return [
            "具备和岗位相关的核心技能，并能用具体案例证明",
            "能清晰沟通、按优先级推进任务并持续跟进结果",
            "能结合目标市场要求说明工作地点、语言和工作权利匹配度",
            "能用可量化成果展示影响力、执行力和学习能力"
        ]
    }

    var jobSearchHealth: JobSearchHealth {
        let profileFields = [
            profile.fullName,
            profile.email,
            profile.phone,
            profile.city,
            profile.targetTitle,
            profile.professionalSummary,
            profile.workHistory,
            profile.education,
            profile.certifications,
            profile.portfolioURL
        ]
        let filledProfileFields = profileFields.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let profileScore = min(35, filledProfileFields * 4 + min(profile.skills.count * 2, 8))

        let pipelineScore = min(25, applications.count * 5)
        let highMatchCount = matchedJobs.prefix(30).filter { $0.score >= 80 }.count
        let matchScore = min(25, highMatchCount * 3)

        let activeApplications = applications.filter { ![.rejected, .offer].contains($0.status) }
        let overdueFollowUps = activeApplications.filter { application in
            guard let followUpDate = application.followUpDate else { return false }
            return followUpDate < Calendar.current.startOfDay(for: Date())
        }.count
        let followUpScore = activeApplications.isEmpty ? 0 : max(0, 15 - overdueFollowUps * 5)

        return JobSearchHealth(
            score: min(100, profileScore + pipelineScore + matchScore + followUpScore),
            profileScore: profileScore,
            pipelineScore: pipelineScore,
            followUpScore: followUpScore,
            matchScore: matchScore
        )
    }

    func marketReadinessPlan() -> MarketReadinessPlan {
        let country = profile.targetCountry
        let dimensions = marketScoreDimensions(for: profile, country: country)
        let score = min(100, dimensions.reduce(0) { $0 + $1.score } * 2)
        let gaps = marketPriorityGaps(for: profile, country: country, dimensions: dimensions)
        let title = "\(t(country.rawValue)) · \(t(country.region.shortTitle))"
        let summary: String

        if usesChineseInterface {
            switch score {
            case 90...100:
                summary = "\(title) 已经接近可投递状态。继续按每个 JD 定制简历、确认工作权利并保持跟进节奏。"
            case 75..<90:
                summary = "\(title) 基础很强，但还有几个会影响面试率的短板。先处理优先动作，再扩大投递量。"
            case 55..<75:
                summary = "\(title) 可以开始筛岗位，但资料、工签或本地化证据会影响面试率。"
            default:
                summary = "\(title) 暂不适合大量投递，先把身份、语言、经历证据和目标国家规则补清楚。"
            }
        } else {
            switch score {
            case 90...100:
                summary = "\(title) is close to application-ready. Keep tailoring each resume, verifying work rights, and following up."
            case 75..<90:
                summary = "\(title) fundamentals are strong, but a few gaps will still reduce interview rate. Fix priority actions before scaling volume."
            case 55..<75:
                summary = "\(title) roles can be screened now, but profile, authorization, or localization gaps will hurt interview rate."
            default:
                summary = "\(title) is not ready for high-volume applications. Clarify authorization, language, evidence, and country rules first."
            }
        }

        return MarketReadinessPlan(
            score: score,
            marketTitle: title,
            summary: summary,
            scoreDimensions: dimensions,
            countryRules: marketCountryRules(for: country),
            resumeRules: marketResumeRules(for: country),
            authorizationChecks: marketAuthorizationChecks(for: country),
            priorityGaps: gaps.isEmpty ? [usesChineseInterface ? "核心资料已经可用，下一步按岗位定制简历并持续跟进。" : "Core profile is usable. Tailor the resume per role and keep following up."] : gaps,
            nextActions: marketNextActions(for: country, gaps: gaps)
        )
    }

    private func marketScoreDimensions(for profile: CandidateProfile, country: TargetCountry) -> [MarketScoreDimension] {
        let chinese = usesChineseInterface
        let profileScore = marketProfileScore(for: profile)
        let evidenceScore = marketEvidenceScore(for: profile)
        let authorizationScore = marketAuthorizationScore(for: profile, country: country)
        let languageScore = marketLanguageScore(for: profile, country: country)
        let executionScore = marketExecutionScore(for: country)

        return [
            MarketScoreDimension(
                title: chinese ? "资料完整度" : "Profile completeness",
                score: profileScore,
                detail: profileScore >= 10
                    ? (chinese ? "联系方式、目标职位、城市、摘要和教育信息已经完整。" : "Contact, target, location, summary, and education are complete.")
                    : (chinese ? "补齐姓名、邮箱、电话、城市、目标职位、摘要和教育信息。" : "Complete name, email, phone, city, target role, summary, and education.")
            ),
            MarketScoreDimension(
                title: chinese ? "简历证据" : "Resume evidence",
                score: evidenceScore,
                detail: evidenceScore >= 10
                    ? (chinese ? "经历、技能、项目和量化成果足够支撑 ATS 与招聘方筛选。" : "Experience, skills, projects, and quantified outcomes are strong enough for ATS and recruiter screening.")
                    : (chinese ? "补 3-5 条量化经历、一个项目案例和岗位关键词技能。" : "Add 3-5 quantified bullets, one project story, and role-specific keywords.")
            ),
            MarketScoreDimension(
                title: chinese ? "工作权利" : "Work rights",
                score: authorizationScore,
                detail: authorizationScore >= 10
                    ? (chinese ? "身份/工签状态已经写得清楚，申请前仍要逐岗位核验。" : "Authorization status is clear. Still verify each role before applying.")
                    : marketAuthorizationGap(for: profile, country: country)
            ),
            MarketScoreDimension(
                title: chinese ? "语言与本地化" : "Language & localization",
                score: languageScore,
                detail: languageScore >= 10
                    ? (chinese ? "语言等级、国家选择和本地证书/表达已经匹配目标市场。" : "Language level, country choice, and local credential wording match the market.")
                    : (chinese ? "补 \(country.languageExpectation)，并把证书/城市/可开始时间写成目标国家习惯。" : "Add \(country.languageExpectation), plus country-specific credential, city, and availability wording.")
            ),
            MarketScoreDimension(
                title: chinese ? "投递执行" : "Application execution",
                score: executionScore,
                detail: executionScore >= 10
                    ? (chinese ? "已有强匹配职位、简历版本和跟进节奏，可以扩大投递。" : "Strong matches, resume versions, and follow-up rhythm are in place.")
                    : (chinese ? "保存市场专用简历，优先投强匹配职位，并设置 3-5 天跟进。" : "Save a market-specific resume, apply to strong matches first, and set 3-5 day follow-ups.")
            )
        ]
    }

    private func marketProfileScore(for profile: CandidateProfile) -> Int {
        var score = 0
        if !profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        if !profile.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        if !profile.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        if !profile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        if !profile.targetTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        if !profile.preferredLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        if profile.professionalSummary.count >= 80 { score += 2 }
        if !profile.education.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        if !profile.portfolioURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        return min(score, 10)
    }

    private func marketEvidenceScore(for profile: CandidateProfile) -> Int {
        var score = 0
        if profile.skills.count >= 6 { score += 2 } else { score += min(profile.skills.count / 2, 2) }
        if profile.workHistory.count >= 180 { score += 3 } else if profile.workHistory.count >= 100 { score += 2 } else if profile.workHistory.count >= 60 { score += 1 }
        if profile.recentExperience.count >= 80 { score += 2 } else if profile.recentExperience.count >= 40 { score += 1 }
        if profile.projectHighlight.count >= 80 { score += 2 } else if profile.projectHighlight.count >= 40 { score += 1 }
        if hasMetricEvidence(in: profile) { score += 1 }
        return min(score, 10)
    }

    private func marketAuthorizationScore(for profile: CandidateProfile, country: TargetCountry) -> Int {
        var score: Int

        switch profile.workAuthorizationStatus {
        case .unknown:
            score = 2
        case .needsSponsorship:
            score = 6
        case .studentOrGraduate:
            score = 6
        case .workingHoliday:
            score = (country == .australia || country == .canada) ? 7 : 5
        case .openWorkPermit:
            score = 8
        case .noSponsorshipNeeded, .permanentResidentOrCitizen:
            score = 9
        case .euEeaCitizen:
            score = country.region == .europe ? 9 : 5
        }

        let note = profile.visaPreference.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty && !note.localizedCaseInsensitiveContains("No preference") {
            score += 1
        }

        return min(score, 10)
    }

    private func marketLanguageScore(for profile: CandidateProfile, country: TargetCountry) -> Int {
        let languages = profile.languages.trimmingCharacters(in: .whitespacesAndNewlines)
        var score = languages.isEmpty ? 0 : 4
        if hasEnglishSignal(languages) { score += 2 }
        if languages.localizedCaseInsensitiveContains("b2") || languages.localizedCaseInsensitiveContains("c1") || languages.localizedCaseInsensitiveContains("c2") {
            score += 2
        }
        if countryNeedsLocalLanguage(country) {
            score += hasLocalLanguageSignal(languages, country: country) ? 2 : 0
        } else {
            score += 2
        }
        if !profile.certifications.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 1 }
        return min(score, 10)
    }

    private func marketExecutionScore(for country: TargetCountry) -> Int {
        var score = 4
        if matchedJobs.prefix(40).contains(where: { $0.score >= 80 && marketCountryMatched($0.job, country: country) }) {
            score += 2
        } else if matchedJobs.prefix(40).contains(where: { $0.score >= 70 }) {
            score += 1
        }
        if resumeVersions.contains(where: { $0.region == country.region }) { score += 2 }
        if applications.contains(where: { application in
            guard let job = jobByID[application.jobID] else { return false }
            return marketCountryMatched(job, country: country)
        }) { score += 1 }
        if settings.followUpReminders { score += 1 }
        return min(score, 10)
    }

    private func marketPriorityGaps(for profile: CandidateProfile, country: TargetCountry, dimensions: [MarketScoreDimension]) -> [String] {
        var gaps: [String] = []
        let chinese = usesChineseInterface

        if profile.workAuthorizationStatus == .unknown {
            gaps.append(chinese ? "把工作权利从“不确定”改成具体状态，并在签证备注里写明路径。" : "Change work rights from not sure to a concrete status and add the path in the visa note.")
        }

        if countryNeedsLocalLanguage(country) && !hasLocalLanguageSignal(profile.languages, country: country) {
            gaps.append(chinese ? "补目标国家语言：\(country.languageExpectation)。" : "Add target-country language: \(country.languageExpectation).")
        } else if !hasEnglishSignal(profile.languages) {
            gaps.append(chinese ? "补英语等级，例如 English C1 或 English B2。" : "Add English level, for example English C1 or English B2.")
        }

        if !hasMetricEvidence(in: profile) {
            gaps.append(chinese ? "经历里补数字结果，例如效率、收入、成本、准确率、用户数或响应时间。" : "Add numeric outcomes, for example efficiency, revenue, cost, accuracy, users, or response time.")
        }

        if profile.workHistory.count < 180 {
            gaps.append(chinese ? "工作经历至少补到 3-5 条要点，写清动作、工具、规模和结果。" : "Expand work history to 3-5 bullets with action, tools, scale, and outcome.")
        }

        if profile.projectHighlight.count < 80 {
            gaps.append(chinese ? "补一个项目/成果案例，用于简历摘要、投递材料和面试 STAR 回答。" : "Add one project or achievement story for resume summary, application materials, and STAR interviews.")
        }

        if profile.skills.count < 6 {
            gaps.append(chinese ? "技能至少补到 6 个，覆盖岗位硬技能、工具和行业关键词。" : "Add at least six skills covering hard skills, tools, and industry keywords.")
        }

        if profile.portfolioURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            gaps.append(chinese ? "补 LinkedIn、作品集、GitHub 或个人网站，方便海外招聘方快速验证。" : "Add LinkedIn, portfolio, GitHub, or a personal site for recruiter verification.")
        }

        if (country.region == .europe || country == .australia) && profile.certifications.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            gaps.append(chinese ? "补证书、执照或本地认可培训，尤其是医疗、教育、财务、合规和现场工作。" : "Add certifications, licenses, or local training, especially for healthcare, education, finance, compliance, and field roles.")
        }

        for dimension in dimensions where dimension.score < 8 && gaps.count < 5 {
            gaps.append(dimension.detail)
        }

        return Array(NSOrderedSet(array: gaps).array.compactMap { $0 as? String }.prefix(5))
    }

    private func marketCountryRules(for country: TargetCountry) -> [String] {
        if usesChineseInterface {
            switch country {
            case .unitedStates:
                return [
                    "美国：优先一页 ATS 简历；不放照片、年龄、婚姻等无关个人信息。",
                    "工签核验看 USCIS/I-9、OPT/STEM OPT、H-1B、TN 等官方路径；STEM OPT 还要确认雇主 E-Verify。",
                    "远程职位也要确认雇主能否在你的州/国家合法雇佣。"
                ]
            case .canada:
                return [
                    "加拿大：按岗位准备 1-2 页简历，突出城市、省份、工作权利和量化结果。",
                    "工签核验看 IRCC、LMIA、开放工签、PR/公民身份和省份限制。",
                    "优先把目标城市写清，例如 Toronto、Vancouver、Montreal 或 Remote Canada。"
                ]
            case .unitedKingdom:
                return [
                    "英国：使用简洁 CV，突出 key achievements、work rights、notice period 和 availability。",
                    "工签核验看 GOV.UK Right to Work、Skilled Worker sponsor、Graduate route。",
                    "不要直接套用美国简历语言，摘要要贴近英国岗位标题和招聘描述。"
                ]
            case .germany:
                return [
                    "德国：英文技术岗位可用英文 CV，本地/客户岗位要准备德语表达和语言等级。",
                    "工签核验看 EU Blue Card、Skilled Worker、学历/资质认可和雇主要求。",
                    "不要写死薪资门槛；蓝卡和工签门槛要申请前查官方最新版本。"
                ]
            case .france:
                return [
                    "法国：本地岗位优先准备法语 CV，国际岗位可保留英文版并补法语等级。",
                    "工签核验看 titre de séjour、Passeport Talent、雇主赞助和职位类别。",
                    "简历要突出目标城市、语言、证书和可开始时间。"
                ]
            case .netherlands:
                return [
                    "荷兰：英文岗位多，但本地/客户岗位写清 Dutch level 会明显加分。",
                    "工签核验看 IND recognized sponsor、Highly Skilled Migrant、EU/EEA 工作权。",
                    "远程或混合岗位要确认居住地、税务雇佣实体和通勤要求。"
                ]
            case .ireland:
                return [
                    "爱尔兰：英文 CV 要简洁，突出可量化结果、notice period、work authorization。",
                    "工签核验看 Critical Skills、General Employment Permit、Stamp/居留状态。",
                    "科技和共享服务岗位要把工具、客户、流程和跨团队协作写清。"
                ]
            case .spain:
                return [
                    "西班牙：本地岗位优先准备西语 CV，国际岗位保留英文版并补 Spanish level。",
                    "工签核验看本地工作许可、EU/EEA 工作权和雇主是否支持非欧盟候选人。",
                    "把目标城市、可开始时间、语言和客户/运营经验写清。"
                ]
            case .sweden:
                return [
                    "瑞典：英文技术岗位可用英文 CV，本地/公共服务岗位要补 Swedish level。",
                    "工签核验看 Swedish Migration Agency、EU/EEA 工作权和雇主申请路径。",
                    "强调协作、可靠交付、工具能力和可量化业务影响。"
                ]
            case .australia:
                return [
                    "澳洲：简历顶部写 work rights、城市、availability 和 onsite/hybrid 适配。",
                    "工签核验看 Home Affairs、VEVO、Student/Graduate、Working Holiday、Skills in Demand 或雇主担保路径。",
                    "现场、医疗、教育、施工和合规岗位要补州/城市证书或执照。"
                ]
            }
        }

        switch country {
        case .unitedStates:
            return [
                "US: prioritize a one-page ATS resume and avoid photo, age, marital status, and unrelated personal details.",
                "Verify USCIS/I-9, OPT/STEM OPT, H-1B, TN, and employer requirements; STEM OPT also needs E-Verify.",
                "Remote roles still require legal hiring ability in your state/country."
            ]
        case .canada:
            return [
                "Canada: use a role-specific 1-2 page resume with city/province, work rights, and quantified outcomes.",
                "Verify IRCC, LMIA, open work permit, PR/citizenship, and province constraints.",
                "State target city clearly, for example Toronto, Vancouver, Montreal, or Remote Canada."
            ]
        case .unitedKingdom:
            return [
                "UK: use a concise CV with key achievements, work rights, notice period, and availability.",
                "Verify GOV.UK Right to Work, Skilled Worker sponsor, and Graduate route.",
                "Do not reuse US resume language unchanged; adapt summary to UK job titles and descriptions."
            ]
        case .germany:
            return [
                "Germany: English CV works for many tech roles; add German level for local or customer-facing roles.",
                "Verify EU Blue Card, Skilled Worker, credential recognition, and employer requirements.",
                "Do not hard-code salary thresholds; check the latest official requirements before applying."
            ]
        case .france:
            return [
                "France: prepare a French CV for local roles; keep English for international roles and add French level.",
                "Verify titre de séjour, Passeport Talent, employer sponsorship, and role category.",
                "State target city, language, credentials, and availability clearly."
            ]
        case .netherlands:
            return [
                "Netherlands: English roles are common, but Dutch level helps for local/customer roles.",
                "Verify IND recognized sponsor, Highly Skilled Migrant, and EU/EEA work rights.",
                "For remote/hybrid roles, confirm residence country, tax employment entity, and commute expectations."
            ]
        case .ireland:
            return [
                "Ireland: keep the English CV concise with quantified impact, notice period, and work authorization.",
                "Verify Critical Skills, General Employment Permit, and Stamp/residence status.",
                "For tech/shared services roles, show tools, customers, process, and cross-team coordination."
            ]
        case .spain:
            return [
                "Spain: prepare a Spanish CV for local roles; keep English for international roles and add Spanish level.",
                "Verify local work permit, EU/EEA work rights, and whether the employer supports non-EU candidates.",
                "State target city, availability, language, and customer/operations experience."
            ]
        case .sweden:
            return [
                "Sweden: English CV can fit technical roles; add Swedish level for local or public-service roles.",
                "Verify Swedish Migration Agency, EU/EEA work rights, and employer application path.",
                "Emphasize collaboration, reliable delivery, tools, and quantified business impact."
            ]
        case .australia:
            return [
                "Australia: put work rights, city, availability, and onsite/hybrid fit near the top.",
                "Verify Home Affairs, VEVO, Student/Graduate, Working Holiday, Skills in Demand, or employer-sponsored path.",
                "For field, healthcare, education, construction, and compliance roles, add state/city licenses."
            ]
        }
    }

    private func marketResumeRules(for country: TargetCountry) -> [String] {
        let chinese = usesChineseInterface
        let localLine = chinese
            ? "语言写成可核验等级：\(country.languageExpectation)。"
            : "State language as verifiable level: \(country.languageExpectation)."
        let metricsLine = chinese
            ? "每条经历尽量写动作、工具、规模和结果，结果用数字支撑。"
            : "Write each bullet with action, tools, scale, and outcome, supported by numbers."

        switch country.region {
        case .northAmerica:
            return chinese ? [
                "使用一页 ATS 简历，顶部放姓名、邮箱、电话、城市和 LinkedIn。",
                "不放照片、年龄、婚姻、国籍等无关个人信息。",
                "每个岗位用 JD 关键词改写 2-3 条经历。",
                metricsLine
            ] : [
                "Use a one-page ATS resume with name, email, phone, city, and LinkedIn at the top.",
                "Avoid photo, age, marital status, nationality, and unrelated personal details.",
                "Tailor 2-3 bullets with exact job-description keywords.",
                metricsLine
            ]
        case .unitedKingdom:
            return chinese ? [
                "使用简洁 CV，突出 key achievements、相关经验和行业关键词。",
                "必要时写 notice period、work rights 和 availability。",
                "摘要按英国岗位标题重写，不直接套美国简历话术。",
                metricsLine
            ] : [
                "Use a concise CV with key achievements, relevant experience, and industry keywords.",
                "Add notice period, work rights, and availability when relevant.",
                "Rewrite the summary around UK job titles rather than US resume language.",
                metricsLine
            ]
        case .europe:
            return chinese ? [
                "按 \(t(country.rawValue)) 调整 CV，不把欧洲当成一个统一规则。",
                localLine,
                "保留英文版，同时为高价值本地岗位准备目标国家语言版本。",
                "学历、证书和工具要写成当地招聘方能理解的表达。"
            ] : [
                "Adjust the CV for \(country.rawValue); do not treat Europe as one uniform rule set.",
                localLine,
                "Keep an English version and prepare a target-country language version for high-value local roles.",
                "Translate education, credentials, and tools into recruiter-readable local wording."
            ]
        case .australia:
            return chinese ? [
                "简历顶部写 work rights、目标城市、availability 和 onsite/hybrid 适配。",
                "用简洁 career summary 开头，避免过度设计。",
                "突出本地客户、现场执行、合规、安全或服务质量。",
                metricsLine
            ] : [
                "Put work rights, target city, availability, and onsite/hybrid fit near the top.",
                "Open with a concise career summary and avoid over-designed layouts.",
                "Emphasize local customer, field, compliance, safety, or service-quality experience.",
                metricsLine
            ]
        }
    }

    private func marketAuthorizationChecks(for country: TargetCountry) -> [String] {
        let chinese = usesChineseInterface
        let status = t(profile.workAuthorizationStatus.rawValue)
        let note = profile.visaPreference.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteLine = note.isEmpty || note.localizedCaseInsensitiveContains("No preference")
            ? (chinese ? "签证备注还未写清，先补具体路径和限制。" : "Visa note is not specific yet; add path and constraints.")
            : (chinese ? "当前备注：\(note)" : "Current note: \(note)")

        if chinese {
            switch country {
            case .unitedStates:
                return [
                    "当前状态：\(status)。确认是否无需赞助、OPT/STEM OPT、H-1B、TN 或其他本地工作权。",
                    "申请前核对 USCIS/I-9 与雇主 sponsorship；STEM OPT 额外确认 E-Verify。",
                    noteLine
                ]
            case .canada:
                return [
                    "当前状态：\(status)。确认 PR/公民、开放工签、LMIA、雇主担保或省份限制。",
                    "申请前用 IRCC/雇主页面核对是否接受你当前身份。",
                    noteLine
                ]
            case .unitedKingdom:
                return [
                    "当前状态：\(status)。确认 Right to Work、Graduate route、Skilled Worker 或无需赞助。",
                    "申请前确认雇主是否在 sponsor list，岗位是否明确支持 sponsorship。",
                    noteLine
                ]
            case .germany:
                return [
                    "当前状态：\(status)。确认 EU Blue Card、Skilled Worker、学历/资质认可和雇主要求。",
                    "申请前核对官方最新门槛，不要依赖旧薪资或旧政策。",
                    noteLine
                ]
            case .france:
                return [
                    "当前状态：\(status)。确认 titre de séjour、Passeport Talent、雇主赞助或本地工作权。",
                    "申请前确认职位类别、合同类型和居留路径是否匹配。",
                    noteLine
                ]
            case .netherlands:
                return [
                    "当前状态：\(status)。确认 IND recognized sponsor、Highly Skilled Migrant 或 EU/EEA 工作权。",
                    "申请前核对雇主是否可担保，以及远程/混合岗位的居住地限制。",
                    noteLine
                ]
            case .ireland:
                return [
                    "当前状态：\(status)。确认 Critical Skills、General Employment Permit、Stamp/居留状态。",
                    "申请前核对职位是否在允许路径内，以及雇主是否能支持许可。",
                    noteLine
                ]
            case .spain:
                return [
                    "当前状态：\(status)。确认本地工作许可、EU/EEA 工作权或雇主担保路径。",
                    "申请前核对职位合同、居住地和远程雇佣限制。",
                    noteLine
                ]
            case .sweden:
                return [
                    "当前状态：\(status)。确认 Swedish Migration Agency 路径、EU/EEA 工作权和雇主申请责任。",
                    "申请前核对岗位、薪资/保险等条件是否满足官方要求。",
                    noteLine
                ]
            case .australia:
                return [
                    "当前状态：\(status)。确认 VEVO、Student/Graduate、Working Holiday、Skills in Demand 或雇主担保路径。",
                    "现场岗位额外核对州/城市执照、安全培训和工作时间限制。",
                    noteLine
                ]
            }
        }

        switch country {
        case .unitedStates:
            return [
                "Current status: \(status). Confirm no sponsorship, OPT/STEM OPT, H-1B, TN, or local work authorization.",
                "Before applying, verify USCIS/I-9 and employer sponsorship; STEM OPT also requires E-Verify.",
                noteLine
            ]
        case .canada:
            return [
                "Current status: \(status). Confirm PR/citizenship, open work permit, LMIA, employer sponsorship, or province limits.",
                "Before applying, verify IRCC and employer pages for your current status.",
                noteLine
            ]
        case .unitedKingdom:
            return [
                "Current status: \(status). Confirm Right to Work, Graduate route, Skilled Worker, or no-sponsorship fit.",
                "Before applying, confirm sponsor-list fit and whether the role supports sponsorship.",
                noteLine
            ]
        case .germany:
            return [
                "Current status: \(status). Confirm EU Blue Card, Skilled Worker, credential recognition, and employer requirements.",
                "Before applying, check the latest official thresholds instead of relying on old policy.",
                noteLine
            ]
        case .france:
            return [
                "Current status: \(status). Confirm titre de séjour, Passeport Talent, employer sponsorship, or local work rights.",
                "Before applying, confirm role category, contract type, and residence path.",
                noteLine
            ]
        case .netherlands:
            return [
                "Current status: \(status). Confirm IND recognized sponsor, Highly Skilled Migrant, or EU/EEA work rights.",
                "Before applying, check sponsor ability plus remote/hybrid residence limits.",
                noteLine
            ]
        case .ireland:
            return [
                "Current status: \(status). Confirm Critical Skills, General Employment Permit, and Stamp/residence status.",
                "Before applying, verify role eligibility and employer permit support.",
                noteLine
            ]
        case .spain:
            return [
                "Current status: \(status). Confirm local work permit, EU/EEA work rights, or employer sponsorship path.",
                "Before applying, verify contract, residence country, and remote employment limits.",
                noteLine
            ]
        case .sweden:
            return [
                "Current status: \(status). Confirm Swedish Migration Agency path, EU/EEA work rights, and employer responsibilities.",
                "Before applying, verify role, salary/insurance, and official conditions.",
                noteLine
            ]
        case .australia:
            return [
                "Current status: \(status). Confirm VEVO, Student/Graduate, Working Holiday, Skills in Demand, or employer-sponsored path.",
                "For field roles, also verify state/city licenses, safety training, and work-hour limits.",
                noteLine
            ]
        }
    }

    private func marketNextActions(for country: TargetCountry, gaps: [String]) -> [String] {
        var actions: [String] = []
        let chinese = usesChineseInterface

        if !gaps.isEmpty {
            actions.append(chinese ? "先处理最影响面试率的资料缺口，再开始批量投递。" : "Fix the profile gaps that most affect interview rate before applying at volume.")
        }

        actions.append(chinese ? "保存一个 \(t(country.rawValue)) 专用简历版本，顶部写清城市、工作权利和联系方式。" : "Save a \(country.rawValue)-specific resume version with city, work rights, and contact details at the top.")

        if countryNeedsLocalLanguage(country) {
            actions.append(chinese ? "为高价值岗位准备英文版 + \(t(country.rawValue)) 本地语言版本。" : "Prepare English plus a local-language version for high-value \(country.rawValue) roles.")
        }

        actions.append(chinese ? "优先申请强匹配且最近发布的岗位，投递后 3-5 天跟进。" : "Prioritize strong, recent roles and follow up after 3-5 days.")
        actions.append(chinese ? "进入职位详情页，用“投递作战”检查缺失关键词、面试题和工签风险。" : "Open job detail strategy cards to check missing keywords, interview prompts, and authorization risk.")

        return Array(actions.prefix(5))
    }

    private func marketAuthorizationGap(for profile: CandidateProfile, country: TargetCountry) -> String {
        let chinese = usesChineseInterface
        switch profile.workAuthorizationStatus {
        case .unknown:
            return chinese ? "还没明确工作权利；先选择具体身份，并补签证/工签备注。" : "Work rights are not clear; choose a concrete status and add a visa/work-rights note."
        case .needsSponsorship:
            return chinese ? "需要赞助；每个岗位先确认雇主是否支持 \(t(country.rawValue)) 的赞助路径。" : "Sponsorship needed; verify each employer supports the \(country.rawValue) path first."
        case .studentOrGraduate:
            return chinese ? "学生/毕业路径要写清到期时间、工作小时限制和是否可转雇主赞助。" : "Student/graduate route needs expiry date, hour limits, and sponsorship transition clarity."
        case .workingHoliday:
            return chinese ? "打工度假路径要写清雇主/工作时长限制和可开始时间。" : "Working holiday route needs employer/work-duration limits and availability."
        case .openWorkPermit:
            return chinese ? "开放工签还需要写清有效期、居住地和是否有岗位限制。" : "Open work permit still needs validity, residence location, and role constraints."
        case .noSponsorshipNeeded, .permanentResidentOrCitizen, .euEeaCitizen:
            return chinese ? "状态基本清楚；再补一句有效期或地区限制，招聘方会更容易判断。" : "Status is mostly clear; add validity or region constraints so recruiters can judge faster."
        }
    }

    private func marketCountryMatched(_ job: Job, country: TargetCountry) -> Bool {
        let searchableLocation = " \(job.city) \(job.remoteType) \(job.summary) \(job.requirements.joined(separator: " ")) ".lowercased()
        let remoteMatched = searchableLocation.contains("remote") || searchableLocation.contains("hybrid")
        return containsAny(country.locationSignals, in: searchableLocation) || remoteMatched
    }

    private func hasMetricEvidence(in profile: CandidateProfile) -> Bool {
        let text = [profile.workHistory, profile.recentExperience, profile.projectHighlight].joined(separator: " ")
        return text.contains("%") || text.range(of: #"\d+"#, options: .regularExpression) != nil
    }

    private func hasEnglishSignal(_ languages: String) -> Bool {
        languages.localizedCaseInsensitiveContains("english") ||
        languages.localizedCaseInsensitiveContains("英语") ||
        languages.localizedCaseInsensitiveContains("英文")
    }

    private func countryNeedsLocalLanguage(_ country: TargetCountry) -> Bool {
        switch country {
        case .germany, .france, .netherlands, .spain, .sweden:
            return true
        case .unitedStates, .canada, .unitedKingdom, .ireland, .australia:
            return false
        }
    }

    private func hasLocalLanguageSignal(_ languages: String, country: TargetCountry) -> Bool {
        let terms: [String]
        switch country {
        case .germany:
            terms = ["german", "deutsch", "德语", "德文"]
        case .france:
            terms = ["french", "français", "francais", "法语", "法文"]
        case .netherlands:
            terms = ["dutch", "nederlands", "荷兰语", "荷兰文"]
        case .spain:
            terms = ["spanish", "español", "espanol", "西语", "西班牙语"]
        case .sweden:
            terms = ["swedish", "svenska", "瑞典语", "瑞典文"]
        case .unitedStates, .canada, .unitedKingdom, .ireland, .australia:
            terms = []
        }
        return terms.contains { languages.localizedCaseInsensitiveContains($0) }
    }

    private func rebuildMatchesImmediately() {
        matchGeneration += 1
        matchRebuildTask?.cancel()
        updateMatchedJobs(Self.buildMatchedJobs(jobs: jobs, profile: profile, feedbackByJobID: feedbackByJobID))
    }

    private func clearLocalizationCaches() {
        localizedTitleCache.removeAll(keepingCapacity: true)
        localizedCompanyCache.removeAll(keepingCapacity: true)
        localizedLocationCache.removeAll(keepingCapacity: true)
        localizedRemoteTypeCache.removeAll(keepingCapacity: true)
        localizedSalaryCache.removeAll(keepingCapacity: true)
        localizedTagCache.removeAll(keepingCapacity: true)
        localizedTextCache.removeAll(keepingCapacity: true)
        localizedReasonCache.removeAll(keepingCapacity: true)
    }

    private func trimLocalizationCacheIfNeeded(_ cache: inout [String: String]) {
        if cache.count > Self.maxLocalizationCacheCount {
            cache.removeAll(keepingCapacity: true)
        }
    }

    nonisolated private static func localizeEnglishPhrase(_ text: String, replacements: [TranslationRule]) -> String {
        var localized = text
        for rule in replacements {
            let range = NSRange(localized.startIndex..<localized.endIndex, in: localized)
            localized = rule.regex.stringByReplacingMatches(
                in: localized,
                options: [],
                range: range,
                withTemplate: rule.replacement
            )
        }

        var range = NSRange(localized.startIndex..<localized.endIndex, in: localized)
        localized = spaceBeforePunctuationRegex.stringByReplacingMatches(
            in: localized,
            options: [],
            range: range,
            withTemplate: "$1"
        )
        range = NSRange(localized.startIndex..<localized.endIndex, in: localized)
        localized = hanCharacterSpacingRegex.stringByReplacingMatches(
            in: localized,
            options: [],
            range: range,
            withTemplate: "$1$2"
        )
        range = NSRange(localized.startIndex..<localized.endIndex, in: localized)
        localized = duplicateSpaceRegex.stringByReplacingMatches(
            in: localized,
            options: [],
            range: range,
            withTemplate: " "
        )
        return localized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func localizeSalaryThousands(_ salary: String) -> String {
        let range = NSRange(salary.startIndex..<salary.endIndex, in: salary)
        guard let match = salaryThousandsRegex.firstMatch(in: salary, options: [], range: range),
              match.numberOfRanges == 3,
              let lowerRange = Range(match.range(at: 1), in: salary),
              let upperRange = Range(match.range(at: 2), in: salary),
              let lower = Double(salary[lowerRange]),
              let upper = Double(salary[upperRange]) else {
            return salary
        }
        return "\(formatTenThousands(lower / 10))万-\(formatTenThousands(upper / 10))万美元"
    }

    nonisolated private static func formatTenThousands(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    nonisolated private static let maxLocalizationCacheCount = 5_000
    nonisolated private static let salaryThousandsRegex = try! NSRegularExpression(pattern: #"^\$(\d+(?:\.\d+)?)k-\$(\d+(?:\.\d+)?)k$"#, options: [.caseInsensitive])
    nonisolated private static let spaceBeforePunctuationRegex = try! NSRegularExpression(pattern: "\\s+([，、；：])")
    nonisolated private static let hanCharacterSpacingRegex = try! NSRegularExpression(pattern: "([\\p{Han}])\\s+([\\p{Han}])")
    nonisolated private static let duplicateSpaceRegex = try! NSRegularExpression(pattern: "\\s{2,}")

    nonisolated private static func makeTranslationRules(_ translations: [String: String]) -> [TranslationRule] {
        translations
            .sorted { $0.key.count > $1.key.count }
            .map { pattern, replacement in
                TranslationRule(
                    regex: try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                    replacement: replacement
                )
            }
    }

    nonisolated private static let companyTranslations: [String: String] = [
        "Airwallex": "空中云汇",
        "OpenAI": "开放人工智能",
        "Collective Health": "集体健康",
        "Rocket Lab Corporation": "火箭实验室",
        "Maven Clinic": "梅文诊所",
        "LaunchDarkly": "暗旗科技",
        "Airtable": "表格协作",
        "Checkr": "背景核验",
        "Thrive Market": "繁荣市场",
        "Canva": "可画",
        "Atlassian": "协作软件",
        "Datadog": "数据监控",
        "Databricks": "数据砖",
        "DoorDash": "门达配送",
        "DoorDash Labs": "门达实验室",
        "Outschool": "课外学校",
        "Northstar Health": "北星健康",
        "Cedar Apps": "雪松应用",
        "BrightCart": "明亮购物车",
        "Atlas Fintech": "阿特拉斯金融科技",
        "Harbor Logistics": "港湾物流",
        "Maple Learning": "枫叶教育"
    ]

    nonisolated private static let locationTranslations: [String: String] = [
        "\\bUS - San Francisco\\b": "美国 - 旧金山",
        "\\bSan Francisco, CA\\b": "旧金山，加州",
        "\\bSan Francisco\\b": "旧金山",
        "\\bNew York, NY\\b": "纽约，纽约州",
        "\\bNew York\\b": "纽约",
        "\\bLos Angeles, CA\\b": "洛杉矶，加州",
        "\\bLos Angeles\\b": "洛杉矶",
        "\\bChicago\\b": "芝加哥",
        "\\bDallas\\b": "达拉斯",
        "\\bAustin\\b": "奥斯汀",
        "\\bSeattle\\b": "西雅图",
        "\\bBoston\\b": "波士顿",
        "\\bLehi, UT \\| Plano, TX\\b": "莱希，犹他州 | 普莱诺，德州",
        "\\bLehi, UT\\b": "莱希，犹他州",
        "\\bPlano, TX\\b": "普莱诺，德州",
        "\\bLehi\\b": "莱希",
        "\\bPlano\\b": "普莱诺",
        "\\bUT\\b": "犹他州",
        "\\bTX\\b": "德州",
        "\\bToronto\\b": "多伦多",
        "\\bVancouver\\b": "温哥华",
        "\\bUnited States\\b": "美国",
        "\\bRemote\\b": "远程",
        "\\bHybrid\\b": "混合办公",
        "\\bOn-site\\b": "现场办公",
        "\\bOnsite\\b": "现场办公"
    ]

    nonisolated private static let jobPhraseTranslations: [String: String] = [
        "\\bSenior Data Scientist, Growth Analytics\\b": "高级数据科学家，增长分析",
        "\\bStaff Data Scientist, Growth Analytics\\b": "资深数据科学家，增长分析",
        "\\bMarket Analytics Lead\\b": "市场分析负责人",
        "\\bData & Reporting Analyst\\b": "数据报告分析师",
        "\\bEntry Level Data Analyst\\b": "初级数据分析师",
        "\\bJunior iOS Developer\\b": "初级 iOS 开发工程师",
        "\\bAdmissions Coordinator\\b": "招生协调员",
        "\\bStrategic Account Executive\\b": "战略客户经理",
        "\\bCustomer Success\\b": "客户成功",
        "\\bCustomer Support\\b": "客户支持",
        "\\bBusiness Development\\b": "业务拓展",
        "\\bEntry Level\\b": "初级",
        "\\bBilingual\\b": "双语",
        "\\bMandarin\\b": "普通话",
        "\\bEnglish\\b": "英语",
        "\\bMachine Learning\\b": "机器学习",
        "\\bData & Analytics\\b": "数据与分析",
        "\\bdata & analytics\\b": "数据与分析",
        "\\bSoftware & IT\\b": "软件与 IT",
        "\\bsoftware & it\\b": "软件与 IT",
        "\\bData Scientist\\b": "数据科学家",
        "\\bData Analyst\\b": "数据分析师",
        "\\bSoftware Engineer\\b": "软件工程师",
        "\\bProduct Manager\\b": "产品经理",
        "\\bProduct Marketing\\b": "产品市场",
        "\\bGrowth Analytics\\b": "增长分析",
        "\\bMarketing Analytics\\b": "市场分析",
        "\\bData Reporting\\b": "数据报告",
        "\\bMarketing\\b": "市场",
        "\\bOperations\\b": "运营",
        "\\bLogistics\\b": "物流",
        "\\bFinance\\b": "财务",
        "\\bAccounting\\b": "会计",
        "\\bRecruiting\\b": "招聘",
        "\\bHuman Resources\\b": "人力资源",
        "\\bHealthcare\\b": "医疗健康",
        "\\bClinical\\b": "临床",
        "\\bEducation\\b": "教育",
        "\\bLegal\\b": "法务",
        "\\bCompliance\\b": "合规",
        "\\bSecurity\\b": "安全",
        "\\bInsurance\\b": "保险",
        "\\bProduction\\b": "生产",
        "\\bDesign\\b": "设计",
        "\\bDesigner\\b": "设计师",
        "\\bDeveloper\\b": "开发工程师",
        "\\bProduct\\b": "产品",
        "\\bData\\b": "数据",
        "\\bAnalytics\\b": "分析",
        "\\bAnalysis\\b": "分析",
        "\\bReporting\\b": "报告",
        "\\bAnalyst\\b": "分析师",
        "\\bScientist\\b": "科学家",
        "\\bEngineer\\b": "工程师",
        "\\bManager\\b": "经理",
        "\\bDirector\\b": "总监",
        "\\bCoordinator\\b": "协调员",
        "\\bSpecialist\\b": "专员",
        "\\bAssociate\\b": "专员",
        "\\bRepresentative\\b": "代表",
        "\\bExecutive\\b": "经理",
        "\\bCounsel\\b": "法律顾问",
        "\\bBackend\\b": "后端",
        "\\bFrontend\\b": "前端",
        "\\bFull Stack\\b": "全栈",
        "\\bGrowth\\b": "增长",
        "\\bSenior\\b": "高级",
        "\\bStaff\\b": "资深",
        "\\bPrincipal\\b": "首席",
        "\\bJunior\\b": "初级",
        "\\bLead\\b": "负责人",
        "\\bBuilder\\b": "建设者",
        "\\bBuilders\\b": "建设者",
        "\\bDevelop\\b": "开发",
        "\\bDevelopment\\b": "开发",
        "\\bMentoring\\b": "指导",
        "\\bLeading\\b": "带领",
        "\\bStatistical\\b": "统计",
        "\\bExperiment\\b": "实验",
        "\\bExperiments\\b": "实验",
        "\\bTesting\\b": "测试",
        "\\bFramework\\b": "框架",
        "\\bFrameworks\\b": "框架",
        "\\bInternship\\b": "实习",
        "\\bIntern\\b": "实习生",
        "\\bAI\\b": "人工智能",
        "\\bPython\\b": "编程语言",
        "\\bSQL\\b": "数据库查询",
        "\\bExcel\\b": "电子表格",
        "\\bCRM\\b": "客户关系管理",
        "\\bAPI\\b": "接口",
        "\\bAWS\\b": "云服务",
        "\\bSwiftUI\\b": "苹果界面开发",
        "\\bSwift\\b": "苹果开发语言",
        "\\bGit\\b": "版本管理",
        "\\bPostgres\\b": "关系型数据库",
        "\\bLinux\\b": "服务器系统",
        "\\bTableau\\b": "数据看板",
        "\\bLooker\\b": "数据看板"
    ]

    nonisolated private static let jobTextTranslations: [String: String] = {
        var translations = jobPhraseTranslations
        translations.merge(locationTranslations) { current, _ in current }
        translations.merge([
            "\\bAnalyze\\b": "分析",
            "\\banalyze\\b": "分析",
            "\\bBuild\\b": "构建",
            "\\bbuild\\b": "构建",
            "\\bSupport\\b": "支持",
            "\\bsupport\\b": "支持",
            "\\bCoordinate\\b": "协调",
            "\\bcoordinate\\b": "协调",
            "\\bDevelop\\b": "开发",
            "\\bdevelop\\b": "开发",
            "\\bManage\\b": "管理",
            "\\bmanage\\b": "管理",
            "\\bcustomer\\b": "客户",
            "\\bcustomers\\b": "客户",
            "\\bteam\\b": "团队",
            "\\bteams\\b": "团队",
            "\\brole\\b": "职位",
            "\\brequirements\\b": "要求",
            "\\bexperience\\b": "经验",
            "\\bproject\\b": "项目",
            "\\bprojects\\b": "项目",
            "\\bworkflow\\b": "工作流",
            "\\bworkflows\\b": "工作流",
            "\\bdashboard\\b": "仪表盘",
            "\\bdashboards\\b": "仪表盘",
            "\\breporting\\b": "报告",
            "\\bcommunication\\b": "沟通",
            "\\boperations\\b": "运营"
        ]) { current, _ in current }
        return translations
    }()

    nonisolated private static let sortedLocationTranslations = makeTranslationRules(locationTranslations)

    nonisolated private static let sortedJobPhraseTranslations = makeTranslationRules(jobPhraseTranslations)

    nonisolated private static let sortedJobTextTranslations = makeTranslationRules(jobTextTranslations)

    private func scheduleMatchRebuild(debounce: Bool) {
        matchGeneration += 1
        let generation = matchGeneration
        let jobsSnapshot = jobs
        let profileSnapshot = profile
        let feedbackSnapshot = feedbackByJobID

        matchRebuildTask?.cancel()
        matchRebuildTask = Task.detached(priority: .utility) { [jobsSnapshot, profileSnapshot, feedbackSnapshot, generation] in
            if debounce {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }

            guard !Task.isCancelled else { return }
            let matches = Self.buildMatchedJobs(
                jobs: jobsSnapshot,
                profile: profileSnapshot,
                feedbackByJobID: feedbackSnapshot
            )
            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self, self.matchGeneration == generation else { return }
                self.updateMatchedJobs(matches)
            }
        }
    }

    private func updateMatchedJobs(_ matches: [JobMatch]) {
        matchByJobID = Dictionary(uniqueKeysWithValues: matches.map { ($0.id, $0) })
        matchedJobs = matches
    }

    func application(for job: Job) -> Application? {
        applicationByJobID[job.id]
    }

    func match(for id: UUID) -> JobMatch? {
        matchByJobID[id]
    }

    func job(for id: UUID) -> Job? {
        jobByID[id]
    }

    func feedback(for job: Job) -> JobFeedback? {
        feedbackByJobID[job.id]
    }

    func save(job: Job, status: ApplicationStatus = .saved) {
        if let index = applications.firstIndex(where: { $0.jobID == job.id }) {
            applications[index].status = status
            applications[index].updatedAt = Date()
        } else {
            applications.append(Application(
                id: UUID(),
                jobID: job.id,
                status: status,
                notes: "",
                draftSubject: nil,
                draftBody: nil,
                followUpDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                createdAt: Date(),
                updatedAt: Date()
            ))
        }
        rebuildApplicationIndex()
        log(.jobSaved, metadata: ["job_id": job.id.uuidString, "status": status.rawValue])
        persistApplications()
    }

    func saveDraft(for job: Job, subject: String, body: String) {
        if let index = applications.firstIndex(where: { $0.jobID == job.id }) {
            applications[index].draftSubject = subject
            applications[index].draftBody = body
            applications[index].updatedAt = Date()
        } else {
            applications.append(Application(
                id: UUID(),
                jobID: job.id,
                status: .saved,
                notes: "",
                draftSubject: subject,
                draftBody: body,
                followUpDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                createdAt: Date(),
                updatedAt: Date()
            ))
        }

        rebuildApplicationIndex()
        log(.draftSaved, metadata: ["job_id": job.id.uuidString])
        persistApplications()
    }

    func update(application: Application) {
        guard let index = applications.firstIndex(where: { $0.id == application.id }) else { return }
        var updated = application
        updated.updatedAt = Date()
        applications[index] = updated
        rebuildApplicationIndex()
        log(.statusChanged, metadata: ["job_id": application.jobID.uuidString, "status": application.status.rawValue])
        persistApplications()
    }

    func recordFeedback(for job: Job, reason: JobFeedbackReason) {
        feedbackByJobID[job.id] = JobFeedback(jobID: job.id, reason: reason, createdAt: Date())
        if reason == .alreadyApplied {
            save(job: job, status: .applied)
        }
        log(.recommendationFeedback, metadata: ["job_id": job.id.uuidString, "reason": reason.rawValue])
        persistFeedback()
        scheduleMatchRebuild(debounce: false)
    }

    func saveProfile() {
        scheduleMatchRebuild(debounce: false)
        log(.profileSaved, metadata: ["target_title": profile.targetTitle, "location": profile.preferredLocation])
        persistProfile()
        Task { await refreshJobsIfNeeded() }
    }

    func useDemoProfile() {
        profile = CandidateProfile(
            fullName: "Alex Chen",
            email: "alex@example.com",
            phone: "(555) 010-2048",
            city: "Los Angeles, CA",
            targetTitle: "Customer Success Associate",
            preferredLocation: "United States",
            workModePreference: .remote,
            opportunityType: .fullTime,
            experienceLevel: .entry,
            visaPreference: "OPT / H-1B friendly preferred",
            workAuthorizationStatus: .studentOrGraduate,
            languages: "English, Mandarin",
            skills: ["Customer Service", "CRM", "Excel", "Communication"],
            professionalSummary: "Customer success and operations candidate with experience organizing customer issues, improving follow-up workflows, and communicating clearly across teams.",
            education: "B.A. Business Administration - University of California, Los Angeles",
            workHistory: "Customer Support Assistant - Campus Services\n- Responded to student and parent questions across email and phone\n- Maintained a shared issue tracker and escalated urgent cases\n- Coordinated weekly reporting for recurring service issues",
            recentExperience: "supporting customers, documenting issues, coordinating follow-ups, and improving response workflows",
            projectHighlight: "Built a customer response tracker that helped a small team reduce missed follow-ups and prioritize urgent requests.",
            certifications: "Google Project Management Certificate",
            portfolioURL: "linkedin.com/in/alexchen",
            resumeTemplate: .customerSuccess,
            resumeRegion: .northAmerica,
            targetCountry: .unitedStates
        )
        log(.demoProfileUsed)
        persistProfile()
        Task { await refreshJobsIfNeeded() }
    }

    func match(job: Job) -> JobMatch {
        Self.match(
            job: job,
            profile: profile,
            signal: Self.resumeSignal(for: profile),
            feedback: feedbackByJobID[job.id],
            feedbackSignal: Self.buildFeedbackSignal(jobs: jobs, feedbackByJobID: feedbackByJobID)
        )
    }

    nonisolated private static func buildMatchedJobs(
        jobs: [Job],
        profile: CandidateProfile,
        feedbackByJobID: [UUID: JobFeedback]
    ) -> [JobMatch] {
        let signal = resumeSignal(for: profile)
        let feedbackSignal = buildFeedbackSignal(jobs: jobs, feedbackByJobID: feedbackByJobID)
        var matches: [JobMatch] = []
        matches.reserveCapacity(jobs.count)

        for job in jobs {
            if Task.isCancelled { return [] }
            matches.append(match(
                job: job,
                profile: profile,
                signal: signal,
                feedback: feedbackByJobID[job.id],
                feedbackSignal: feedbackSignal
            ))
        }

        return matches.sorted {
            if $0.score == $1.score {
                return $0.job.postedDate > $1.job.postedDate
            }
            return $0.score > $1.score
        }
    }

    nonisolated private static func match(
        job: Job,
        profile: CandidateProfile,
        signal: ResumeSignal,
        feedback: JobFeedback?,
        feedbackSignal: FeedbackSignal
    ) -> JobMatch {
        let normalizedTitle = job.title.lowercased()
        let targetTitle = profile.targetTitle.lowercased()
        let preferredLocation = profile.preferredLocation.lowercased()
        let normalizedJobTags = normalizedTags(for: job)
        let jobTags = Set(normalizedJobTags.map { $0.lowercased() })
        let jobText = [
            job.title,
            job.company,
            job.city,
            job.remoteType,
            normalizedJobTags.joined(separator: " "),
            job.summary,
            job.requirements.joined(separator: " ")
        ].joined(separator: " ")
        let searchableJobText = " \(jobText.lowercased()) "
        let jobTokens = Set(tokenize(jobText))

        var score = 12
        var reasons: [String] = []

        let titleOverlap = Set(normalizedTitle.split(separator: " ").map(String.init))
            .intersection(Set(targetTitle.split(separator: " ").map(String.init)))
            .filter { $0.count > 2 }

        if normalizedTitle.contains(targetTitle) ||
            targetTitle.contains(normalizedTitle.components(separatedBy: " ").first ?? "") ||
            titleOverlap.count >= 2 {
            score += 25
            reasons.append("Title aligns with your target role")
        }

        let sharedSkills = signal.skills.intersection(jobTags)
        if !sharedSkills.isEmpty {
            let skillScore = min(sharedSkills.count * 8, 30)
            score += skillScore
            reasons.append("Skills matched: \(sharedSkills.sorted().joined(separator: ", "))")
        }

        let resumeKeywordMatches = signal.weightedKeywords
            .filter { jobTokens.contains($0.term) }
            .prefix(8)
        if !resumeKeywordMatches.isEmpty {
            let keywordScore = min(resumeKeywordMatches.reduce(0) { $0 + $1.weight }, 22)
            score += keywordScore
            let terms = resumeKeywordMatches.prefix(4).map(\.term).joined(separator: ", ")
            reasons.append("Resume keywords matched: \(terms)")
        }

        let requirementMatches = signal.requirementTerms
            .filter { term in job.requirements.contains { $0.localizedCaseInsensitiveContains(term) } }
            .prefix(5)
        if !requirementMatches.isEmpty {
            score += min(requirementMatches.count * 4, 16)
            reasons.append("Role requirements overlap with your resume")
        }

        let sharedCategories = signal.categories.intersection(jobTags)
        if !sharedCategories.isEmpty {
            score += min(sharedCategories.count * 10, 18)
            reasons.append("Industry fit: \(sharedCategories.sorted().joined(separator: ", "))")
        }

        if !preferredLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           job.city.lowercased().contains(preferredLocation) {
            score += 15
            reasons.append("Location preference fits")
        }

        if workModeFits(job: job, profile: profile) {
            score += 10
            reasons.append("Work mode fits")
        } else if profile.workModePreference != .any {
            score -= 10
        }

        if opportunityFits(job: job, profile: profile) {
            score += 10
            reasons.append("Opportunity type fits")
        } else if profile.opportunityType != .any {
            score -= 8
        }

        if countryMatches(searchableJobText, country: profile.targetCountry) {
            score += 12
            reasons.append("Target country fits")
        } else if searchableJobText.contains(" remote ") || searchableJobText.contains(" hybrid ") {
            score += 4
            reasons.append("Remote role still needs hiring-country check")
        } else {
            score -= 8
        }

        if job.visaFriendly {
            score += 10
            reasons.append("Tagged as visa friendly")
        } else {
            switch profile.workAuthorizationStatus {
            case .unknown:
                score -= 5
                reasons.append("Work authorization needs clarification")
            case .needsSponsorship, .studentOrGraduate:
                score -= 3
                reasons.append("Sponsorship fit needs checking")
            case .noSponsorshipNeeded, .openWorkPermit, .permanentResidentOrCitizen, .workingHoliday, .euEeaCitizen:
                score += 8
                reasons.append("Work rights look actionable")
            }
        }

        if experienceFits(title: normalizedTitle, profile: profile) {
            score += 10
            reasons.append("Experience level looks aligned")
        }

        if feedbackSignal.tooSenior && titleLooksSenior(normalizedTitle) {
            score -= 25
        }

        if feedbackSignal.unwantedLocations.contains(normalized(job.city)) ||
            feedbackSignal.unwantedLocations.contains(normalized(job.remoteType)) {
            score -= 18
        }

        let unwantedIndustryOverlap = feedbackSignal.unwantedIndustries.intersection(jobTags)
        if !unwantedIndustryOverlap.isEmpty {
            score -= 18
        }

        if let feedback {
            score -= feedback.reason.exactPenalty
            reasons.append("Adjusted from your feedback: \(feedback.reason.rawValue)")
        }

        if reasons.isEmpty {
            reasons.append("Some profile details match this role")
        }

        return JobMatch(job: job, score: min(max(score, 0), 100), reasons: reasons)
    }

    nonisolated private static func buildFeedbackSignal(
        jobs: [Job],
        feedbackByJobID: [UUID: JobFeedback]
    ) -> FeedbackSignal {
        var tooSenior = false
        var unwantedLocations = Set<String>()
        var unwantedIndustries = Set<String>()
        let jobByID = Dictionary(uniqueKeysWithValues: jobs.map { ($0.id, $0) })

        for feedback in feedbackByJobID.values {
            guard let job = jobByID[feedback.jobID] else { continue }
            switch feedback.reason {
            case .tooSenior:
                tooSenior = true
            case .wrongLocation:
                unwantedLocations.insert(normalized(job.city))
                unwantedLocations.insert(normalized(job.remoteType))
            case .wrongIndustry:
                unwantedIndustries.formUnion(job.tags.map { $0.lowercased() })
            case .notRelevant, .salaryTooLow, .alreadyApplied:
                break
            }
        }

        return FeedbackSignal(
            tooSenior: tooSenior,
            unwantedLocations: unwantedLocations,
            unwantedIndustries: unwantedIndustries
        )
    }

    nonisolated private static func resumeSignal(for profile: CandidateProfile) -> ResumeSignal {
        let resumeText = [
            profile.targetTitle,
            profile.skills.joined(separator: " "),
            profile.professionalSummary,
            profile.workHistory,
            profile.recentExperience,
            profile.projectHighlight,
            profile.education,
            profile.certifications,
            profile.languages,
            profile.resumeTemplate.title
        ].joined(separator: " ")

        var frequencies: [String: Int] = [:]
        for token in tokenize(resumeText) {
            frequencies[token, default: 0] += 1
        }

        let boostedTerms = Set(tokenize([
            profile.targetTitle,
            profile.skills.joined(separator: " "),
            profile.certifications
        ].joined(separator: " ")))

        let weightedKeywords = frequencies
            .map { term, count in
                let boost = boostedTerms.contains(term) ? 5 : 0
                return WeightedTerm(term: term, weight: min(count * 3 + boost, 12))
            }
            .sorted {
                if $0.weight == $1.weight { return $0.term < $1.term }
                return $0.weight > $1.weight
            }

        let categories = inferResumeCategories(from: resumeText, resumeTemplate: profile.resumeTemplate)
        let requirementTerms = Set(tokenize([
            profile.skills.joined(separator: " "),
            profile.workHistory,
            profile.recentExperience,
            profile.projectHighlight,
            profile.certifications
        ].joined(separator: " ")))

        return ResumeSignal(
            skills: Set(profile.skills.map { $0.lowercased() }),
            weightedKeywords: weightedKeywords,
            categories: categories,
            requirementTerms: requirementTerms
        )
    }

    nonisolated private static func experienceFits(title: String, profile: CandidateProfile) -> Bool {
        switch profile.experienceLevel {
        case .internship:
            return title.contains("intern") || title.contains("trainee") || title.contains("student")
        case .entry:
            return title.contains("junior") || title.contains("associate") || title.contains("entry") || title.contains("coordinator") || title.contains("assistant")
        case .mid:
            return !title.contains("senior") && !title.contains("staff") && !title.contains("principal") && !title.contains("director") && !title.contains("vp")
        case .senior:
            return title.contains("senior") || title.contains("lead") || title.contains("staff") || title.contains("principal") || title.contains("manager")
        }
    }

    nonisolated private static func workModeFits(job: Job, profile: CandidateProfile) -> Bool {
        let mode = profile.workModePreference
        guard mode != .any else { return true }
        let text = "\(job.remoteType) \(job.city) \(job.summary) \(job.tags.joined(separator: " "))".lowercased()

        switch mode {
        case .any:
            return true
        case .remote:
            return text.contains("remote")
        case .hybrid:
            return text.contains("hybrid")
        case .onSite:
            return text.contains("on-site") || text.contains("onsite") || text.contains("office") || text.contains("in person")
        }
    }

    nonisolated private static func opportunityFits(job: Job, profile: CandidateProfile) -> Bool {
        let type = profile.opportunityType
        guard type != .any else { return true }
        let text = "\(job.title) \(job.summary) \(job.tags.joined(separator: " ")) \(job.requirements.joined(separator: " "))".lowercased()

        switch type {
        case .any:
            return true
        case .internship:
            return text.contains("intern") || text.contains("internship") || text.contains("student") || text.contains("graduate")
        case .fullTime:
            return !text.contains("internship") && !text.contains("part-time") && !text.contains("part time") && !text.contains("contract")
        case .partTime:
            return text.contains("part-time") || text.contains("part time")
        case .contract:
            return text.contains("contract") || text.contains("temporary")
        }
    }

    nonisolated private static func titleLooksSenior(_ title: String) -> Bool {
        title.contains("senior") ||
        title.contains("staff") ||
        title.contains("principal") ||
        title.contains("director") ||
        title.contains("vp") ||
        title.contains("head of")
    }

    nonisolated private static func normalizedTags(for job: Job) -> [String] {
        var tags = job.tags
        let title = job.title.lowercased()
        let searchable = [
            job.title,
            job.summary,
            job.requirements.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        if isTechnicalResearchRole(title) || isDataRole(searchable) {
            tags.removeAll { $0.lowercased() == "sales & business development" || $0.lowercased() == "sales" }
            if !tags.contains(where: { $0.localizedCaseInsensitiveCompare("Data & Analytics") == .orderedSame }) {
                tags.insert("Data & Analytics", at: 0)
            }
        }

        if isTechnicalResearchRole(searchable),
           !tags.contains(where: { $0.localizedCaseInsensitiveCompare("Software & IT") == .orderedSame }) {
            tags.append("Software & IT")
        }

        return Array(NSOrderedSet(array: tags).array.compactMap { $0 as? String })
    }

    nonisolated private static func isTechnicalResearchRole(_ text: String) -> Bool {
        [
            "research scientist",
            "data scientist",
            "machine learning",
            "ml engineer",
            "ai researcher",
            "applied scientist",
            "research engineer"
        ].contains { text.contains($0) }
    }

    nonisolated private static func isDataRole(_ text: String) -> Bool {
        [
            "data analyst",
            "analytics",
            "business intelligence",
            "data engineer",
            "quantitative",
            "experiment analysis"
        ].contains { text.contains($0) }
    }

    nonisolated private static func inferResumeCategories(from text: String, resumeTemplate: ResumeTemplate) -> Set<String> {
        let lower = text.lowercased()
        var categories = Set<String>()

        let templateCategory: [ResumeTemplate: String] = [
            .operations: "operations & logistics",
            .sales: "sales & business development",
            .customerSuccess: "customer support & success",
            .healthcare: "healthcare & clinical",
            .student: "education & training",
            .fieldWork: "manufacturing & field work",
            .creative: "marketing & content"
        ]

        if let category = templateCategory[resumeTemplate] {
            categories.insert(category)
        }

        let rules: [(String, [String])] = [
            ("software & it", ["software", "developer", "engineer", "ios", "android", "python", "swift", "javascript", "cloud", "security", "api"]),
            ("data & analytics", ["data", "analytics", "sql", "dashboard", "tableau", "looker", "reporting", "insights"]),
            ("operations & logistics", ["operations", "logistics", "supply", "warehouse", "inventory", "dispatch", "fulfillment", "process"]),
            ("sales & business development", ["sales", "account", "pipeline", "revenue", "prospect", "business development", "partnership"]),
            ("customer support & success", ["customer", "support", "crm", "success", "ticket", "retention", "onboarding"]),
            ("marketing & content", ["marketing", "content", "campaign", "seo", "copywriting", "social media", "brand"]),
            ("finance & accounting", ["finance", "accounting", "payroll", "audit", "tax", "bookkeeping", "fp&a"]),
            ("healthcare & clinical", ["healthcare", "clinical", "patient", "medical", "nursing", "therapy", "pharmacy"]),
            ("education & training", ["teacher", "education", "student", "curriculum", "tutor", "admissions", "training"]),
            ("manufacturing & field work", ["manufacturing", "technician", "maintenance", "field", "safety", "hvac", "production"]),
            ("legal & compliance", ["legal", "compliance", "contract", "policy", "privacy", "regulatory"]),
            ("hr & recruiting", ["recruiting", "talent", "human resources", "hr", "benefits", "compensation"]),
            ("retail & hospitality", ["retail", "store", "restaurant", "hospitality", "food service", "guest"]),
            ("administrative", ["administrative", "assistant", "receptionist", "office", "coordinator"])
        ]

        for (category, keywords) in rules where keywords.contains(where: { lower.contains($0) }) {
            categories.insert(category)
        }

        return categories
    }

    nonisolated private static func tokenize(_ text: String) -> [String] {
        let stopWords: Set<String> = [
            "the", "and", "for", "with", "from", "that", "this", "you", "your", "our", "are", "was", "were",
            "have", "has", "had", "will", "can", "into", "about", "across", "within", "role", "work", "team",
            "experience", "skills", "strong", "using", "able", "candidate", "resume", "job", "jobs", "add",
            "level", "targeting", "preferred", "remote", "summary"
        ]

        return text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 && !stopWords.contains($0) && !$0.allSatisfy(\.isNumber) }
    }

    nonisolated private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    nonisolated private static func countryMatches(_ text: String, country: TargetCountry) -> Bool {
        country.locationSignals.contains { text.contains($0) }
    }

    nonisolated private static func recommendedResumeTemplate(for job: Job) -> ResumeTemplate {
        let title = job.title.lowercased()
        let text = [
            job.title,
            job.remoteType,
            normalizedTags(for: job).joined(separator: " "),
            job.summary,
            job.requirements.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        if isTechnicalResearchRole(title) || isDataRole(title) {
            return .atsClassic
        }

        if text.contains("intern") || text.contains("student") || text.contains("campus") || text.contains("graduate") {
            return .student
        }

        if text.contains("healthcare") || text.contains("clinical") || text.contains("patient") || text.contains("nursing") || text.contains("medical") {
            return .healthcare
        }

        if text.contains("sales") || text.contains("account executive") || text.contains("business development") || text.contains("pipeline") || text.contains("revenue") {
            return .sales
        }

        if text.contains("customer success") || text.contains("customer support") || text.contains("support specialist") || text.contains("crm") {
            return .customerSuccess
        }

        if text.contains("operations") || text.contains("logistics") || text.contains("supply chain") || text.contains("warehouse") || text.contains("procurement") {
            return .operations
        }

        if text.contains("technician") || text.contains("manufacturing") || text.contains("field service") || text.contains("maintenance") || text.contains("safety") {
            return .fieldWork
        }

        if text.contains("marketing") || text.contains("content") || text.contains("designer") || text.contains("brand") || text.contains("creative") {
            return .creative
        }

        if text.contains("software") || text.contains("engineer") || text.contains("developer") || text.contains("data") || text.contains("analyst") || text.contains("finance") || text.contains("legal") {
            return .atsClassic
        }

        return .modernSnapshot
    }

    func generateMessage(for job: Job) -> GeneratedMessage {
        log(.applicationGenerated, metadata: ["job_id": job.id.uuidString])
        let topSkills = profile.skills.prefix(3).joined(separator: ", ")
        let greeting = job.contactEmail == nil ? "Hi \(job.company) recruiting team," : "Hi team,"
        let experience = profile.recentExperience.isEmpty ? "my recent work and project experience" : profile.recentExperience
        let project = profile.projectHighlight.isEmpty ? "I can share more context on relevant projects if helpful." : "One relevant project: \(profile.projectHighlight)"
        let jobDescription = jobDescriptionText(for: job)
        let resume = generateResumeText(
            template: recommendedResumeTemplate(for: job),
            region: profile.resumeRegion,
            targetJobTitle: job.title,
            company: job.company,
            jobDescription: jobDescription
        )

        let subject = "\(profile.fullName.isEmpty ? "Application" : profile.fullName) - \(job.title)"
        let body = """
        \(greeting)

        I am interested in the \(job.title) role at \(job.company). My background in \(topSkills) and \(experience) seems aligned with the role.

        \(project)

        I would appreciate the opportunity to be considered. I included a plain-text resume summary below for quick review.

        ---
        \(resume)

        Best,
        \(profile.fullName)
        \(profile.email)
        \(profile.phone)
        """

        return GeneratedMessage(subject: subject, body: body)
    }

    func jobDescriptionText(for job: Job) -> String {
        [
            job.title,
            job.company,
            job.summary,
            job.requirements.joined(separator: "\n"),
            displayTags(for: job).joined(separator: ", ")
        ]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    func recommendedResumeTemplate(for job: Job) -> ResumeTemplate {
        Self.recommendedResumeTemplate(for: job)
    }

    func applicationPlan(for match: JobMatch) -> JobApplicationPlan {
        let job = match.job
        let jobDescription = jobDescriptionText(for: job)
        let recommendedTemplate = recommendedResumeTemplate(for: job)
        let targetedResume = generateResumeText(
            template: recommendedTemplate,
            region: profile.resumeRegion,
            targetJobTitle: job.title,
            company: job.company,
            jobDescription: jobDescription
        )
        let audit = analyzeResumeText(targetedResume, targetJobTitle: job.title, jobDescription: jobDescription)
        let marketFit = marketFitLine(for: job)
        let authorizationFit = authorizationFitLine(for: job)
        let resumeFocus = applicationFocusLine(for: job.title, keywords: Array(Self.priorityTerms(from: jobDescription, fallback: profile.skills).prefix(6)))

        var readiness = Int((Double(match.score) * 0.45 + Double(audit.score) * 0.45 + Double(audit.keywordCoverage) * 0.10).rounded())
        if job.visaFriendly { readiness += 5 }
        readiness = min(100, max(0, readiness))

        var actions: [String] = [
            t("Save a targeted resume version for this role"),
            t("Mirror the top missing keywords in 2-3 bullets"),
            job.contactEmail == nil ? t("Use the apply link and keep a follow-up date") : t("Send a concise recruiter message after applying")
        ]

        if !job.visaFriendly && profile.visaPreference.localizedCaseInsensitiveContains("sponsor") {
            actions.append(t("Check the employer's sponsorship policy before spending more time"))
        }

        if audit.score < 70 {
            actions.append(t("Rewrite the resume before applying"))
        }

        return JobApplicationPlan(
            readinessScore: readiness,
            marketFit: marketFit,
            authorizationFit: authorizationFit,
            recommendedTemplate: recommendedTemplate,
            resumeFocus: resumeFocus,
            missingKeywords: Array(audit.missingKeywords.prefix(6)),
            nextActions: Array(actions.prefix(5)),
            interviewPrompts: interviewPrompts(for: job)
        )
    }

    func saveTargetedResume(for match: JobMatch) -> Int {
        saveTargetedResume(for: match.job)
    }

    func saveTargetedResume(for job: Job) -> Int {
        let jobDescription = jobDescriptionText(for: job)
        let template = recommendedResumeTemplate(for: job)
        let resume = generateResumeText(
            template: template,
            region: profile.resumeRegion,
            targetJobTitle: job.title,
            company: job.company,
            jobDescription: jobDescription
        )
        let audit = analyzeResumeText(resume, targetJobTitle: job.title, jobDescription: jobDescription)
        saveResumeVersion(
            name: "\(job.title) - \(job.company)",
            text: resume,
            template: template,
            region: profile.resumeRegion,
            targetTitle: job.title,
            company: job.company,
            sourceJobID: job.id,
            atsScore: audit.score
        )
        return audit.score
    }

    func saveEditedTargetedResume(for job: Job, text: String, name: String = "") -> Int {
        let jobDescription = jobDescriptionText(for: job)
        let template = recommendedResumeTemplate(for: job)
        let audit = analyzeResumeText(text, targetJobTitle: job.title, jobDescription: jobDescription)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        saveResumeVersion(
            name: trimmedName.isEmpty ? "\(job.title) - \(job.company)" : trimmedName,
            text: text,
            template: template,
            region: profile.resumeRegion,
            targetTitle: job.title,
            company: job.company,
            sourceJobID: job.id,
            atsScore: audit.score
        )

        return audit.score
    }

    func saveMarketResumeVersion() -> Int {
        let country = profile.targetCountry
        let resume = generateResumeText(
            template: profile.resumeTemplate,
            region: country.region,
            targetJobTitle: profile.targetTitle,
            company: "",
            jobDescription: ""
        )
        let audit = analyzeResumeText(resume, targetJobTitle: profile.targetTitle)
        saveResumeVersion(
            name: "\(country.shortTitle) - \(profile.targetTitle)",
            text: resume,
            template: profile.resumeTemplate,
            region: country.region,
            targetTitle: profile.targetTitle,
            company: country.rawValue,
            atsScore: audit.score
        )
        return audit.score
    }

    func workRightsResumeLine() -> String {
        let country = profile.targetCountry.rawValue
        let note = profile.visaPreference.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = note.isEmpty || note.localizedCaseInsensitiveContains("No preference") ? "" : " \(note)"
        let line: String

        switch profile.workAuthorizationStatus {
        case .unknown:
            line = "Work authorization: To be confirmed for \(country)."
        case .noSponsorshipNeeded:
            line = "Work authorization: Authorized to work in \(country); no employer sponsorship required."
        case .needsSponsorship:
            line = "Work authorization: Employer sponsorship required for \(country)."
        case .studentOrGraduate:
            line = "Work authorization: Student or graduate work route for \(country); details available on request."
        case .openWorkPermit:
            line = "Work authorization: Open work authorization for \(country)."
        case .permanentResidentOrCitizen:
            line = "Work authorization: Citizen, permanent resident, or settled status for \(country); no sponsorship required."
        case .workingHoliday:
            line = "Work authorization: Working holiday route for \(country); confirm employer and duration limits."
        case .euEeaCitizen:
            if profile.targetCountry.region == .europe {
                line = "Work authorization: EU/EEA work rights for \(country)."
            } else {
                line = "Work authorization: EU/EEA work rights; confirm separate authorization for \(country)."
            }
        }

        return "\(line)\(suffix)"
    }

    func generateResumeText(
        template: ResumeTemplate? = nil,
        region: ResumeRegion? = nil,
        targetJobTitle: String = "",
        company: String = "",
        jobDescription: String = ""
    ) -> String {
        let selectedTemplate = template ?? profile.resumeTemplate
        let selectedRegion = region ?? profile.resumeRegion
        let baseResume: String

        switch selectedTemplate {
        case .atsClassic:
            baseResume = atsClassicResume()
        case .modernSnapshot:
            baseResume = modernSnapshotResume()
        case .operations:
            baseResume = operationsResume()
        case .sales:
            baseResume = salesResume()
        case .customerSuccess:
            baseResume = customerSuccessResume()
        case .healthcare:
            baseResume = healthcareResume()
        case .student:
            baseResume = studentResume()
        case .fieldWork:
            baseResume = fieldWorkResume()
        case .creative:
            baseResume = creativeResume()
        }

        return finalizeResume(
            baseResume,
            region: selectedRegion,
            targetJobTitle: targetJobTitle,
            company: company,
            jobDescription: jobDescription
        )
    }

    func analyzeResumeText(_ resumeText: String, targetJobTitle: String = "", jobDescription: String = "") -> ATSResumeAudit {
        let trimmedResume = resumeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResume.isEmpty else { return .empty }

        let resumeTokens = Set(Self.resumeTokens(trimmedResume))
        let keywordSource = [targetJobTitle, jobDescription, profile.skills.joined(separator: " "), profile.certifications]
            .joined(separator: " ")
        let keywords = Array(Self.priorityTerms(from: keywordSource, fallback: [profile.targetTitle] + profile.skills).prefix(18))
        let missing = keywords.filter { !resumeTokens.contains($0) }
        let matchedCount = max(0, keywords.count - missing.count)
        let keywordCoverage = keywords.isEmpty ? 100 : Int((Double(matchedCount) / Double(keywords.count) * 100).rounded())
        let lower = trimmedResume.lowercased()
        let wordCount = Self.resumeTokens(trimmedResume).count

        var score = 18
        var strengths: [String] = []
        var warnings: [String] = []

        if lower.contains("@") || lower.range(of: #"\d{3}[-.)\s]?\d{3}[-.\s]?\d{4}"#, options: .regularExpression) != nil {
            score += 8
            strengths.append(t("Contact information is visible"))
        } else {
            warnings.append(t("Add email and phone near the top"))
        }

        let sectionChecks: [(String, Int, String)] = [
            ("summary", 10, "Summary/objective section is present"),
            ("skills", 12, "Skills section is easy to scan"),
            ("experience", 14, "Experience section is present"),
            ("education", 8, "Education section is present")
        ]

        for (section, points, strength) in sectionChecks {
            if lower.contains(section) {
                score += points
                strengths.append(t(strength))
            } else {
                let heading = settings.language == .chinese ? section.uppercased() : section.uppercased()
                warnings.append(settings.language == .chinese ? "添加清晰的 \(heading) 标题" : "Add a clear \(heading) heading")
            }
        }

        score += min(30, Int((Double(keywordCoverage) / 100.0 * 30.0).rounded()))
        if keywordCoverage >= 70 {
            strengths.append(t("Keyword coverage is strong for the target role"))
        } else if !keywords.isEmpty {
            warnings.append(t("Add more exact terms from the job description"))
        }

        switch wordCount {
        case 280...850:
            score += 10
            strengths.append(t("Length is within a practical ATS range"))
        case 0..<280:
            warnings.append(t("Resume is short; add measurable experience bullets"))
        default:
            warnings.append(t("Resume is long; trim older or unrelated details"))
        }

        if lower.contains("|") && lower.components(separatedBy: "|").count > 8 {
            warnings.append(t("Too many separator-heavy lines can reduce scan quality"))
        } else {
            score += 4
        }

        return ATSResumeAudit(
            score: min(score, 100),
            keywordCoverage: keywordCoverage,
            missingKeywords: Array(missing.prefix(8)),
            strengths: Array(strengths.prefix(5)),
            warnings: Array(warnings.prefix(5)),
            wordCount: wordCount
        )
    }

    func rewriteResumeDraft(_ text: String, targetJobTitle: String = "", jobDescription: String = "") -> String {
        let target = targetJobTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? profile.targetTitle : targetJobTitle
        let actionVerb = Self.actionVerb(for: target)
        let keywords = Self.priorityTerms(
            from: [target, jobDescription].joined(separator: " "),
            fallback: profile.skills
        ).prefix(10)

        let rewrittenLines = text.components(separatedBy: .newlines).map { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return line }
            guard trimmed.hasPrefix("-") || trimmed.hasPrefix("•") else { return line }

            let bullet = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = bullet.lowercased()
            let strongVerbs = ["built", "led", "managed", "created", "improved", "analyzed", "coordinated", "delivered", "supported", "designed", "implemented", "increased", "reduced"]
            let startsStrong = strongVerbs.contains { lower.hasPrefix($0) }
            let improved = startsStrong ? bullet : "\(actionVerb) \(bullet.prefix(1).lowercased())\(bullet.dropFirst())"
            return "- \(Self.ensureSentence(improved))"
        }

        var output = rewrittenLines.joined(separator: "\n")
        if !keywords.isEmpty && !output.localizedCaseInsensitiveContains("Targeted keywords") {
            output += "\n\nTARGETED KEYWORDS\n\(keywords.joined(separator: " | "))"
        }
        return output
    }

    func saveResumeVersion(
        name: String,
        text: String,
        template: ResumeTemplate,
        region: ResumeRegion,
        targetTitle: String,
        company: String,
        sourceJobID: UUID? = nil,
        atsScore: Int
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionName = trimmedName.isEmpty ? "\(targetTitle.isEmpty ? profile.targetTitle : targetTitle) - \(region.shortTitle)" : trimmedName
        let now = Date()

        let existingIndex: Int?
        if let sourceJobID {
            existingIndex = resumeVersions.firstIndex(where: { $0.sourceJobID == sourceJobID })
        } else if let selectedResumeVersionID {
            existingIndex = resumeVersions.firstIndex(where: { $0.id == selectedResumeVersionID })
        } else {
            existingIndex = nil
        }

        if let index = existingIndex {
            resumeVersions[index].name = versionName
            resumeVersions[index].template = template
            resumeVersions[index].region = region
            resumeVersions[index].targetTitle = targetTitle.isEmpty ? profile.targetTitle : targetTitle
            resumeVersions[index].company = company
            resumeVersions[index].sourceJobID = sourceJobID
            resumeVersions[index].resumeText = text
            resumeVersions[index].atsScore = atsScore
            resumeVersions[index].updatedAt = now
        } else {
            let version = ResumeVersion(
                id: UUID(),
                name: versionName,
                template: template,
                region: region,
                targetTitle: targetTitle.isEmpty ? profile.targetTitle : targetTitle,
                company: company,
                sourceJobID: sourceJobID,
                resumeText: text,
                atsScore: atsScore,
                createdAt: now,
                updatedAt: now
            )
            resumeVersions.insert(version, at: 0)
            selectedResumeVersionID = version.id
        }

        if resumeVersions.count > 30 {
            resumeVersions.removeLast(resumeVersions.count - 30)
        }

        log(.resumeVersionSaved, metadata: ["target_title": targetTitle, "region": region.rawValue])
        persistResumeVersions()
    }

    func selectResumeVersion(_ version: ResumeVersion) -> String {
        selectedResumeVersionID = version.id
        profile.resumeTemplate = version.template
        profile.resumeRegion = version.region
        persistProfile()
        return version.resumeText
    }

    func deleteResumeVersion(_ version: ResumeVersion) {
        resumeVersions.removeAll { $0.id == version.id }
        if selectedResumeVersionID == version.id {
            selectedResumeVersionID = nil
        }
        persistResumeVersions()
    }

    private func finalizeResume(
        _ baseResume: String,
        region: ResumeRegion,
        targetJobTitle: String,
        company: String,
        jobDescription: String
    ) -> String {
        var sections = [baseResume.trimmingCharacters(in: .whitespacesAndNewlines)]

        if let targetBlock = targetedRoleBlock(
            targetJobTitle: targetJobTitle,
            company: company,
            jobDescription: jobDescription
        ) {
            sections.append(targetBlock)
        }

        sections.append(regionResumeBlock(region))
        return sections.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func targetedRoleBlock(targetJobTitle: String, company: String, jobDescription: String) -> String? {
        let target = targetJobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let company = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty || !company.isEmpty || !description.isEmpty else { return nil }

        let keywords = Self.priorityTerms(
            from: [target, description].joined(separator: " "),
            fallback: profile.skills + [profile.targetTitle]
        ).prefix(12)
        let focus = Self.focusLine(for: target.isEmpty ? profile.targetTitle : target, keywords: Array(keywords))

        return """
        TARGETED ROLE FIT
        Role: \(target.isEmpty ? profile.targetTitle : target)\(company.isEmpty ? "" : " at \(company)")
        Priority keywords: \(keywords.isEmpty ? "Add a job description to extract keywords" : keywords.joined(separator: " | "))
        Application focus: \(focus)
        """
    }

    private func regionResumeBlock(_ region: ResumeRegion) -> String {
        let targetCountry = profile.targetCountry.region == region ? profile.targetCountry.rawValue : region.shortTitle
        let workStatus = profile.workAuthorizationStatus.rawValue

        switch region {
        case .northAmerica:
            return """
            \(region.resumeSectionTitle)
            Target market: \(targetCountry)
            Work authorization status: \(workStatus)
            Work authorization preference: \(profile.visaPreference)
            Format: \(region.guidance)
            """
        case .australia:
            return """
            \(region.resumeSectionTitle)
            Target market: \(targetCountry)
            Work authorization status: \(workStatus)
            Work rights / visa note: \(profile.visaPreference)
            Location preference: \(profile.preferredLocation)
            Format: \(region.guidance)
            """
        case .unitedKingdom:
            return """
            \(region.resumeSectionTitle)
            Target market: \(targetCountry)
            Work authorization status: \(workStatus)
            Work rights / visa note: \(profile.visaPreference)
            Location preference: \(profile.preferredLocation)
            Format: \(region.guidance)
            """
        case .europe:
            return """
            \(region.resumeSectionTitle)
            Target market: \(targetCountry)
            Languages: \(profile.languages)
            Work authorization status: \(workStatus)
            Work authorization preference: \(profile.visaPreference)
            Format: \(region.guidance)
            """
        }
    }

    private func marketFitLine(for job: Job) -> String {
        let targetMarket = t(profile.resumeRegion.shortTitle)
        let searchableLocation = " \(job.city) \(job.remoteType) \(job.summary) ".lowercased()
        let remoteMatched = searchableLocation.contains("remote") || searchableLocation.contains("hybrid")
        let regionMatched: Bool

        switch profile.resumeRegion {
        case .northAmerica:
            regionMatched = containsAny(
                [" united states ", " usa ", " us ", " canada ", " new york ", " san francisco ", " los angeles ", " chicago ", " dallas ", " toronto ", " vancouver ", " seattle ", " boston ", " austin "],
                in: searchableLocation
            )
        case .australia:
            regionMatched = containsAny(
                [" australia ", " sydney ", " melbourne ", " brisbane ", " perth ", " adelaide ", " canberra "],
                in: searchableLocation
            )
        case .unitedKingdom:
            regionMatched = containsAny(
                [" united kingdom ", " uk ", " london ", " manchester ", " birmingham ", " edinburgh ", " leeds "],
                in: searchableLocation
            )
        case .europe:
            regionMatched = containsAny(
                [" europe ", " eu ", " germany ", " berlin ", " munich ", " france ", " paris ", " netherlands ", " amsterdam ", " ireland ", " dublin ", " spain ", " madrid ", " portugal ", " lisbon ", " poland ", " warsaw ", " sweden ", " stockholm "],
                in: searchableLocation
            )
        }

        if regionMatched || remoteMatched {
            return usesChineseInterface ? "目标市场匹配：\(targetMarket)" : "Target market matched: \(targetMarket)"
        }

        return usesChineseInterface
            ? "目标市场需确认：\(targetMarket)，申请前核对是否接受当地或远程候选人"
            : "Target market needs review: \(targetMarket). Check whether this employer accepts local or remote candidates."
    }

    private func authorizationFitLine(for job: Job) -> String {
        let preference = profile.visaPreference.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = preference.lowercased()
        let needsSponsorshipCheck = lower.contains("sponsor") ||
            lower.contains("visa") ||
            lower.contains("h-1b") ||
            lower.contains("opt") ||
            lower.contains("工签") ||
            lower.contains("签证") ||
            lower.contains("赞助")

        if job.visaFriendly {
            return usesChineseInterface
                ? "工签/签证：岗位标记为友好，申请前仍需确认雇主政策和身份要求"
                : "Work authorization: marked visa friendly. Still confirm employer policy and eligibility requirements."
        }

        if needsSponsorshipCheck {
            return usesChineseInterface
                ? "工签/签证：未标记友好，优先确认是否赞助或接受你的身份类型"
                : "Work authorization: not marked visa friendly. Confirm sponsorship or work-rights fit first."
        }

        return usesChineseInterface
            ? "工签/签证：按你的偏好继续核对工作权利、开始日期和地点限制"
            : "Work authorization: check work rights, start date, and location constraints against your preference."
    }

    private func applicationFocusLine(for target: String, keywords: [String]) -> String {
        guard usesChineseInterface else {
            return Self.focusLine(for: target, keywords: keywords)
        }

        let lower = target.lowercased()
        if lower.contains("software") || lower.contains("engineer") || lower.contains("developer") {
            return "简历优先突出技术项目、上线系统、工具能力，以及可靠性或产品影响。"
        }
        if lower.contains("data") || lower.contains("analyst") || lower.contains("research scientist") || lower.contains("machine learning") || lower.contains("applied scientist") {
            return "简历优先突出分析工具、回答过的业务问题、仪表盘，以及带来的决策改进。"
        }
        if lower.contains("sales") || lower.contains("account") {
            return "简历优先突出销售管道、客户沟通、转化率，以及收入相关结果。"
        }
        if lower.contains("customer") || lower.contains("support") || lower.contains("success") {
            return "简历优先突出客户处理、问题解决、CRM 规范、留存和服务质量。"
        }
        if lower.contains("operations") || lower.contains("logistics") {
            return "简历优先突出流程负责、协调能力、吞吐量、准确率和跨团队执行。"
        }
        if let first = keywords.first {
            return "简历优先用 \(localizedJobTag(first)) 相关证据、可量化结果和岗位工具来支撑。"
        }
        return "简历优先突出可量化结果、相关工具，以及最能证明岗位胜任力的证据。"
    }

    private func interviewPrompts(for job: Job) -> [String] {
        let searchable = "\(job.title) \(displayTags(for: job).joined(separator: " ")) \(job.summary) \(job.requirements.joined(separator: " "))".lowercased()

        if containsAny(["data", "analyst", "analytics", "dashboard", "sql", "research scientist", "data scientist", "machine learning", "applied scientist"], in: searchable) {
            return usesChineseInterface ? [
                "准备一个用数据影响业务决策的 STAR 案例。",
                "准备说明你如何定义指标、清理数据并解释结果。",
                "准备一个和非技术同事沟通分析结论的例子。"
            ] : [
                "Prepare a STAR story where data changed a business decision.",
                "Prepare how you defined metrics, cleaned data, and explained results.",
                "Prepare an example of communicating analysis to non-technical stakeholders."
            ]
        }

        if containsAny(["software", "engineer", "developer", "backend", "frontend", "full stack"], in: searchable) {
            return usesChineseInterface ? [
                "准备一个从需求到上线的项目案例，讲清技术取舍。",
                "准备说明你如何处理性能、可靠性或错误排查。",
                "准备一个和产品/设计/业务协作推进交付的例子。"
            ] : [
                "Prepare a shipped project story from requirements to launch, including tradeoffs.",
                "Prepare how you handled performance, reliability, or debugging.",
                "Prepare an example of working with product, design, or business partners."
            ]
        }

        if containsAny(["sales", "account", "pipeline", "revenue", "business development"], in: searchable) {
            return usesChineseInterface ? [
                "准备一个推进销售管道或客户转化的案例。",
                "准备说明你如何处理客户异议和下一步承诺。",
                "准备一个用数据管理目标、跟进和结果的例子。"
            ] : [
                "Prepare a story about moving pipeline or improving conversion.",
                "Prepare how you handled customer objections and next-step commitments.",
                "Prepare an example of managing targets, follow-ups, and results with data."
            ]
        }

        if containsAny(["customer", "support", "success", "crm", "retention"], in: searchable) {
            return usesChineseInterface ? [
                "准备一个处理困难客户并恢复信任的案例。",
                "准备说明你如何记录、升级和关闭问题。",
                "准备一个提升留存、满意度或响应效率的例子。"
            ] : [
                "Prepare a story about handling a difficult customer and rebuilding trust.",
                "Prepare how you documented, escalated, and closed issues.",
                "Prepare an example of improving retention, satisfaction, or response speed."
            ]
        }

        if containsAny(["operations", "logistics", "warehouse", "coordinator", "supply"], in: searchable) {
            return usesChineseInterface ? [
                "准备一个发现流程瓶颈并提升效率的案例。",
                "准备说明你如何协调多方、截止时间和异常情况。",
                "准备一个减少错误、提升准确率或吞吐量的例子。"
            ] : [
                "Prepare a story about finding a process bottleneck and improving efficiency.",
                "Prepare how you coordinated stakeholders, deadlines, and exceptions.",
                "Prepare an example of reducing errors or improving accuracy or throughput."
            ]
        }

        return usesChineseInterface ? [
            "准备一个最能证明岗位胜任力的 STAR 案例。",
            "准备说明你为什么适合这个市场、地点和工作方式。",
            "准备一个可量化成果，突出你的贡献和下一步成长。"
        ] : [
            "Prepare a STAR story that best proves fit for this role.",
            "Prepare why you fit this market, location, and work style.",
            "Prepare one measurable outcome that shows contribution and growth."
        ]
    }

    private func containsAny(_ terms: [String], in text: String) -> Bool {
        terms.contains { text.contains($0) }
    }

    private static func priorityTerms(from text: String, fallback: [String]) -> [String] {
        var counts: [String: Int] = [:]
        for token in resumeTokens(text) {
            counts[token, default: 0] += 2
        }
        for token in resumeTokens(fallback.joined(separator: " ")) {
            counts[token, default: 0] += 1
        }

        return counts
            .filter { $0.key.count >= 3 }
            .sorted {
                if $0.value == $1.value { return $0.key < $1.key }
                return $0.value > $1.value
            }
            .map(\.key)
    }

    private static func resumeTokens(_ text: String) -> [String] {
        let stopWords: Set<String> = [
            "the", "and", "for", "with", "from", "that", "this", "you", "your", "our", "are", "was", "were",
            "have", "has", "had", "will", "can", "into", "about", "across", "within", "role", "work", "team",
            "experience", "skills", "strong", "using", "able", "candidate", "resume", "job", "jobs", "add",
            "level", "targeting", "preferred", "remote", "summary", "responsibilities", "requirements",
            "including", "looking", "ability", "based", "teams", "company", "business"
        ]

        return text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 && !stopWords.contains($0) && !$0.allSatisfy(\.isNumber) }
    }

    private static func focusLine(for target: String, keywords: [String]) -> String {
        let lower = target.lowercased()
        if lower.contains("software") || lower.contains("engineer") || lower.contains("developer") {
            return "Lead with technical projects, shipped systems, tools, and measurable reliability or product impact."
        }
        if lower.contains("data") || lower.contains("analyst") || lower.contains("research scientist") || lower.contains("machine learning") || lower.contains("applied scientist") {
            return "Lead with analytical tools, business questions answered, dashboards, and decisions improved."
        }
        if lower.contains("sales") || lower.contains("account") {
            return "Lead with pipeline ownership, customer communication, conversion, and revenue-related outcomes."
        }
        if lower.contains("customer") || lower.contains("support") || lower.contains("success") {
            return "Lead with customer handling, issue resolution, CRM hygiene, retention, and service quality."
        }
        if lower.contains("operations") || lower.contains("logistics") {
            return "Lead with process ownership, coordination, throughput, accuracy, and cross-functional execution."
        }
        if let first = keywords.first {
            return "Lead with evidence around \(first), measurable outcomes, and role-specific tools."
        }
        return "Lead with measurable outcomes, relevant tools, and the strongest evidence for this role."
    }

    private static func actionVerb(for target: String) -> String {
        let lower = target.lowercased()
        if lower.contains("data") || lower.contains("analyst") { return "Analyzed" }
        if lower.contains("software") || lower.contains("engineer") || lower.contains("developer") { return "Built" }
        if lower.contains("sales") || lower.contains("account") { return "Managed" }
        if lower.contains("customer") || lower.contains("support") || lower.contains("success") { return "Supported" }
        if lower.contains("operations") || lower.contains("coordinator") || lower.contains("logistics") { return "Coordinated" }
        if lower.contains("marketing") || lower.contains("content") { return "Created" }
        return "Delivered"
    }

    private static func ensureSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, !".!?".contains(last) else { return trimmed }
        return "\(trimmed)."
    }

    private var resumeName: String {
        profile.fullName.isEmpty ? "Your Name" : profile.fullName
    }

    private var resumeContactLine: String {
        [profile.email, profile.phone, profile.city, profile.portfolioURL]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }

    private var resumeSkillsLine: String {
        profile.skills.isEmpty ? "Add skills in Profile" : profile.skills.joined(separator: " | ")
    }

    private var resumeSummary: String {
        if !profile.professionalSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return profile.professionalSummary
        }

        let experience = profile.recentExperience.isEmpty ? "relevant experience" : profile.recentExperience
        return "\(profile.experienceLevel.rawValue) candidate targeting \(profile.targetTitle), with \(experience)."
    }

    private var resumeExperience: String {
        if !profile.workHistory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return profile.workHistory
        }

        return profile.recentExperience.isEmpty ? "Add work history or recent experience in Profile." : profile.recentExperience
    }

    private var resumeProject: String {
        profile.projectHighlight.isEmpty ? "Add a project, achievement, portfolio item, or measurable result." : profile.projectHighlight
    }

    private var resumeEducation: String {
        profile.education.isEmpty ? "Add school, degree, training, or relevant coursework." : profile.education
    }

    private var resumeCertifications: String {
        profile.certifications.isEmpty ? "Add licenses, certificates, tools, or safety training." : profile.certifications
    }

    private func atsClassicResume() -> String {
        let skills = profile.skills.isEmpty ? "Add skills in Profile" : profile.skills.joined(separator: " | ")

        return """
        \(resumeName)
        \(resumeContactLine)

        TARGET ROLE
        \(profile.targetTitle) | \(profile.preferredLocation) | \(profile.experienceLevel.rawValue)

        PROFESSIONAL SUMMARY
        \(resumeSummary)

        SKILLS
        \(skills)

        EXPERIENCE
        \(resumeExperience)

        PROJECT HIGHLIGHT
        \(resumeProject)

        EDUCATION
        \(resumeEducation)

        CERTIFICATIONS
        \(resumeCertifications)

        LANGUAGES
        \(profile.languages)
        """
    }

    private func modernSnapshotResume() -> String {
        """
        \(resumeName)
        \(profile.targetTitle) | \(profile.preferredLocation)
        \(resumeContactLine)

        SNAPSHOT
        \(resumeSummary)

        CORE SKILLS
        \(resumeSkillsLine)

        SELECTED EXPERIENCE
        \(resumeExperience)

        FEATURED RESULT
        \(resumeProject)

        EDUCATION + CREDENTIALS
        \(resumeEducation)
        \(resumeCertifications)
        """
    }

    private func operationsResume() -> String {
        """
        \(resumeName)
        Operations Resume - \(profile.targetTitle)
        \(resumeContactLine)

        OPERATIONS PROFILE
        \(resumeSummary)

        PROCESS + TOOLS
        \(resumeSkillsLine)

        EXECUTION HISTORY
        \(resumeExperience)

        IMPROVEMENT HIGHLIGHT
        \(resumeProject)

        EDUCATION / CERTIFICATIONS
        \(resumeEducation)
        \(resumeCertifications)
        """
    }

    private func salesResume() -> String {
        """
        \(resumeName)
        Sales Resume - \(profile.targetTitle)
        \(resumeContactLine)

        SALES SUMMARY
        \(resumeSummary)

        GTM SKILLS
        \(resumeSkillsLine)

        CUSTOMER / PIPELINE EXPERIENCE
        \(resumeExperience)

        DEAL OR OUTREACH HIGHLIGHT
        \(resumeProject)

        EDUCATION / TRAINING
        \(resumeEducation)
        \(resumeCertifications)
        """
    }

    private func customerSuccessResume() -> String {
        """
        \(resumeName)
        Customer Success Resume - \(profile.targetTitle)
        \(resumeContactLine)

        CUSTOMER PROFILE
        \(resumeSummary)

        SUPPORT + CRM SKILLS
        \(resumeSkillsLine)

        CUSTOMER EXPERIENCE
        \(resumeExperience)

        RETENTION / SERVICE HIGHLIGHT
        \(resumeProject)

        EDUCATION / CERTIFICATIONS
        \(resumeEducation)
        \(resumeCertifications)
        """
    }

    private func healthcareResume() -> String {
        """
        \(resumeName)
        Healthcare Resume - \(profile.targetTitle)
        \(resumeContactLine)

        CARE PROFILE
        \(resumeSummary)

        CLINICAL / ADMINISTRATIVE SKILLS
        \(resumeSkillsLine)

        PATIENT OR OPERATIONS EXPERIENCE
        \(resumeExperience)

        CARE QUALITY HIGHLIGHT
        \(resumeProject)

        EDUCATION / LICENSES
        \(resumeEducation)
        \(resumeCertifications)
        """
    }

    private func studentResume() -> String {
        """
        \(resumeName)
        Student / Entry Resume - \(profile.targetTitle)
        \(resumeContactLine)

        OBJECTIVE
        \(resumeSummary)

        SKILLS
        \(resumeSkillsLine)

        EDUCATION
        \(resumeEducation)

        PROJECTS / CAMPUS EXPERIENCE
        \(resumeProject)

        EXPERIENCE
        \(resumeExperience)

        ACTIVITIES / CERTIFICATIONS
        \(resumeCertifications)
        """
    }

    private func fieldWorkResume() -> String {
        """
        \(resumeName)
        Field Work Resume - \(profile.targetTitle)
        \(resumeContactLine)

        FIELD PROFILE
        \(resumeSummary)

        TOOLS / SAFETY / TECHNICAL SKILLS
        \(resumeSkillsLine)

        HANDS-ON EXPERIENCE
        \(resumeExperience)

        RELIABILITY HIGHLIGHT
        \(resumeProject)

        TRAINING / CERTIFICATIONS
        \(resumeEducation)
        \(resumeCertifications)
        """
    }

    private func creativeResume() -> String {
        """
        \(resumeName)
        Creative Resume - \(profile.targetTitle)
        \(resumeContactLine)

        CREATIVE PROFILE
        \(resumeSummary)

        CREATIVE + BUSINESS SKILLS
        \(resumeSkillsLine)

        CAMPAIGN / CONTENT EXPERIENCE
        \(resumeExperience)

        PORTFOLIO HIGHLIGHT
        \(resumeProject)

        EDUCATION / TOOLS
        \(resumeEducation)
        \(resumeCertifications)
        """
    }

    func log(_ name: AnalyticsEventName, metadata: [String: String] = [:]) {
        analyticsEvents.append(AnalyticsEvent(id: UUID(), name: name, metadata: metadata, createdAt: Date()))
        if analyticsEvents.count > 500 {
            analyticsEvents.removeFirst(analyticsEvents.count - 500)
        }

        switch name {
        case .applicationGenerated:
            analyticsCounters.generated += 1
        case .applyLinkOpened, .emailOpened:
            analyticsCounters.opened += 1
        default:
            break
        }

        scheduleAnalyticsPersist()
    }

    func resetLocalData() {
        profile = CandidateProfile()
        applications = []
        applicationByJobID = [:]
        feedbackByJobID = [:]
        resumeVersions = []
        selectedResumeVersionID = nil
        analyticsEvents = []
        analyticsCounters = AnalyticsCounters()
        settings = AppSettings()
        analyticsPersistTask?.cancel()
        UserDefaults.standard.removeObject(forKey: profileKey)
        UserDefaults.standard.removeObject(forKey: applicationsKey)
        UserDefaults.standard.removeObject(forKey: feedbackKey)
        UserDefaults.standard.removeObject(forKey: resumeVersionsKey)
        UserDefaults.standard.removeObject(forKey: analyticsKey)
        UserDefaults.standard.removeObject(forKey: settingsKey)
    }

    func refreshJobsIfNeeded(force: Bool = false) async {
        guard jobFeedConfig.remoteURL != nil || jobFeedConfig.remoteIndexURL != nil else { return }

        if !force,
           let lastRefresh = UserDefaults.standard.object(forKey: lastJobRefreshKey) as? Date,
           Date().timeIntervalSince(lastRefresh) < TimeInterval(jobFeedConfig.refreshIntervalHours * 3600) {
            return
        }

        let freshnessWindow = max(jobFeedConfig.refreshIntervalHours + 12, 36)

        if jobFeedConfig.remoteIndexURL != nil {
            if await refreshJobSlices(freshnessWindow: freshnessWindow) {
                UserDefaults.standard.set(Date(), forKey: lastJobRefreshKey)
                return
            }

            if await refreshFullJobFeed(freshnessWindow: freshnessWindow) {
                UserDefaults.standard.set(Date(), forKey: lastJobRefreshKey)
            }
        } else if await refreshFullJobFeed(freshnessWindow: freshnessWindow) {
            UserDefaults.standard.set(Date(), forKey: lastJobRefreshKey)
        }
    }

    private func refreshFullJobFeed(freshnessWindow: Int) async -> Bool {
        guard let remoteURL = jobFeedConfig.remoteURL else { return false }

        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return false
            }

            let refreshedRecords = await Task.detached(priority: .utility) {
                Job.decodeSeedJobRecords(
                    from: data,
                    requireRecentVerification: true,
                    maxAgeHours: freshnessWindow
                )
            }.value

            guard refreshedRecords.count >= jobFeedConfig.minimumLiveJobs else { return false }

            apply(seedJobRecords: refreshedRecords)
            cache(seedJobRecords: refreshedRecords)
            return true
        } catch {
            return false
        }
    }

    private func refreshJobSlices(freshnessWindow: Int) async -> Bool {
        guard let indexURL = jobFeedConfig.remoteIndexURL else { return false }

        do {
            let (indexData, indexResponse) = try await URLSession.shared.data(from: indexURL)
            guard let httpResponse = indexResponse as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let index = try? JSONDecoder().decode(JobFeedIndex.self, from: indexData) else {
                return false
            }

            let descriptors = preferredSlices(from: index)
            guard !descriptors.isEmpty else { return false }

            var recordsByID = await existingSeedJobRecords(freshnessWindow: freshnessWindow)

            for descriptor in descriptors {
                guard let sliceURL = resolvedFeedURL(descriptor.url, relativeTo: indexURL) else { continue }
                guard let records = try? await fetchSeedJobRecords(from: sliceURL, freshnessWindow: freshnessWindow) else { continue }

                for record in records {
                    recordsByID[record.id] = record
                }
            }

            let mergedRecords = recordsByID.values.sorted {
                if $0.postedDaysAgo == $1.postedDaysAgo {
                    if $0.company == $1.company {
                        return $0.title < $1.title
                    }
                    return $0.company < $1.company
                }
                return $0.postedDaysAgo < $1.postedDaysAgo
            }

            guard mergedRecords.count >= jobFeedConfig.startupMinimum else { return false }

            apply(seedJobRecords: mergedRecords)
            cache(seedJobRecords: mergedRecords)
            return true
        } catch {
            return false
        }
    }

    private func existingSeedJobRecords(freshnessWindow: Int) async -> [String: SeedJob] {
        let cachedData = UserDefaults.standard.data(forKey: cachedJobsKey)
        let seedURL = Bundle.main.url(forResource: "SeedJobs", withExtension: "json")

        return await Task.detached(priority: .utility) {
            var recordsByID: [String: SeedJob] = [:]

            if let cachedData {
                for record in Job.decodeSeedJobRecords(
                    from: cachedData,
                    requireRecentVerification: true,
                    maxAgeHours: freshnessWindow
                ) {
                    recordsByID[record.id] = record
                }
            }

            if let seedURL,
               let data = try? Data(contentsOf: seedURL) {
                for record in Job.decodeSeedJobRecords(
                    from: data,
                    requireRecentVerification: true,
                    maxAgeHours: freshnessWindow
                ) {
                    recordsByID[record.id] = record
                }
            }

            return recordsByID
        }.value
    }

    private func fetchSeedJobRecords(from url: URL, freshnessWindow: Int) async throws -> [SeedJob] {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return []
        }

        return await Task.detached(priority: .utility) {
            Job.decodeSeedJobRecords(
                from: data,
                requireRecentVerification: true,
                maxAgeHours: freshnessWindow
            )
        }.value
    }

    private func preferredSlices(from index: JobFeedIndex) -> [JobFeedSliceDescriptor] {
        let profileText = [
            profile.targetTitle,
            profile.preferredLocation,
            profile.targetCountry.rawValue,
            profile.workModePreference.rawValue,
            profile.opportunityType.rawValue,
            profile.skills.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        let featuredIDs = Set(index.featuredSliceIds ?? [])
        let targetLocation = Self.feedLocationSlug(for: profile.targetCountry)

        return index.slices
            .map { descriptor -> (descriptor: JobFeedSliceDescriptor, score: Int) in
                var score = featuredIDs.contains(descriptor.id) ? 8 : 0
                let searchable = [
                    descriptor.id,
                    descriptor.title,
                    descriptor.category ?? "",
                    descriptor.workMode ?? "",
                    descriptor.opportunityType ?? "",
                    descriptor.locations?.joined(separator: " ") ?? "",
                    descriptor.keywords?.joined(separator: " ") ?? ""
                ].joined(separator: " ").lowercased()

                for term in profileText.components(separatedBy: CharacterSet.alphanumerics.inverted) where term.count >= 3 {
                    if searchable.contains(term) { score += 3 }
                }

                if descriptor.locations?.contains(targetLocation) == true { score += 12 }
                if descriptor.locations?.contains("global") == true { score += 2 }
                if profile.workModePreference == .remote && descriptor.workMode == "remote" { score += 12 }
                if profile.workModePreference == .hybrid && descriptor.workMode == "hybrid" { score += 8 }
                if profile.workModePreference == .onSite && descriptor.workMode == "on-site" { score += 8 }
                if profile.opportunityType == .internship && descriptor.opportunityType == "internship" { score += 12 }
                if profile.opportunityType == .fullTime && descriptor.opportunityType == "full-time" { score += 8 }
                if descriptor.id == "featured" { score += 10 }
                if descriptor.id == "remote" && profile.workModePreference == .remote { score += 10 }

                return (descriptor, score)
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.descriptor.jobCount > $1.descriptor.jobCount
                }
                return $0.score > $1.score
            }
            .prefix(jobFeedConfig.sliceLimit)
            .map(\.descriptor)
    }

    private static func feedLocationSlug(for country: TargetCountry) -> String {
        switch country {
        case .unitedStates: return "united-states"
        case .canada: return "canada"
        case .unitedKingdom: return "united-kingdom"
        case .australia: return "australia"
        case .germany, .france, .netherlands, .ireland, .spain, .sweden: return "europe"
        }
    }

    private func resolvedFeedURL(_ value: String, relativeTo baseURL: URL) -> URL? {
        if let absoluteURL = URL(string: value), absoluteURL.scheme != nil {
            return absoluteURL
        }

        return URL(string: value, relativeTo: baseURL)?.absoluteURL
    }

    private func apply(seedJobRecords records: [SeedJob]) {
        jobs = records.map(\.job)
        rebuildMatchesImmediately()
    }

    private func cache(seedJobRecords records: [SeedJob]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: cachedJobsKey)
    }

    private func loadInitialJobs() async {
        let cachedData = UserDefaults.standard.data(forKey: cachedJobsKey)
        let freshnessWindow = max(jobFeedConfig.refreshIntervalHours + 12, 36)
        let minimumLiveJobs = jobFeedConfig.startupMinimum
        let seedURL = Bundle.main.url(forResource: "SeedJobs", withExtension: "json")

        let initialJobs = await Task.detached(priority: .utility) {
            if let cachedData {
                let cachedJobs = Job.decodeSeedJobs(
                    from: cachedData,
                    requireRecentVerification: true,
                    maxAgeHours: freshnessWindow
                )

                if cachedJobs.count >= minimumLiveJobs {
                    return cachedJobs
                }
            }

            guard let seedURL,
                  let data = try? Data(contentsOf: seedURL) else {
                return Job.fallbackSeed
            }

            let seedJobs = Job.decodeSeedJobs(
                from: data,
                requireRecentVerification: true,
                maxAgeHours: freshnessWindow
            )
            return seedJobs.isEmpty ? Job.fallbackSeed : seedJobs
        }.value

        jobs = initialJobs
        rebuildMatchesImmediately()
        isLoadingJobs = false
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(CandidateProfile.self, from: data) {
            profile = normalizedLoadedProfile(decoded)
        }

        if let data = UserDefaults.standard.data(forKey: applicationsKey),
           let decoded = try? JSONDecoder().decode([Application].self, from: data) {
            applications = decoded
        }
        rebuildApplicationIndex()

        if let data = UserDefaults.standard.data(forKey: feedbackKey),
           let decoded = try? JSONDecoder().decode([JobFeedback].self, from: data) {
            feedbackByJobID = Dictionary(uniqueKeysWithValues: decoded.map { ($0.jobID, $0) })
        }

        if let data = UserDefaults.standard.data(forKey: resumeVersionsKey),
           let decoded = try? JSONDecoder().decode([ResumeVersion].self, from: data) {
            resumeVersions = decoded.sorted { $0.updatedAt > $1.updatedAt }
        }

        if let data = UserDefaults.standard.data(forKey: analyticsKey),
           let decoded = try? JSONDecoder().decode([AnalyticsEvent].self, from: data) {
            analyticsEvents = decoded
        }
        rebuildAnalyticsCounters()

        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
    }

    private func normalizedLoadedProfile(_ decoded: CandidateProfile) -> CandidateProfile {
        var normalized = decoded

        if normalized.targetCountry.region != normalized.resumeRegion {
            normalized.targetCountry = normalized.resumeRegion.defaultTargetCountry
        }

        let legacyLocation = normalized.preferredLocation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["remote", "hybrid", "on-site", "onsite"].contains(legacyLocation) {
            normalized.workModePreference = CandidateProfile.inferredWorkMode(from: normalized.preferredLocation)
            normalized.preferredLocation = ""
        }

        let inferredAuthorization = WorkAuthorizationStatus.inferred(from: normalized.visaPreference)
        if normalized.workAuthorizationStatus == .permanentResidentOrCitizen,
           [.studentOrGraduate, .needsSponsorship, .openWorkPermit, .workingHoliday].contains(inferredAuthorization) {
            normalized.workAuthorizationStatus = inferredAuthorization
        }

        return normalized
    }

    private func persistProfile() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: profileKey)
    }

    private func rebuildApplicationIndex() {
        applicationByJobID = Dictionary(uniqueKeysWithValues: applications.map { ($0.jobID, $0) })
    }

    private func rebuildJobIndex() {
        jobByID = Dictionary(uniqueKeysWithValues: jobs.map { ($0.id, $0) })
    }

    private func rebuildAnalyticsCounters() {
        analyticsCounters = AnalyticsCounters(
            generated: analyticsEvents.filter { $0.name == .applicationGenerated }.count,
            opened: analyticsEvents.filter { $0.name == .applyLinkOpened || $0.name == .emailOpened }.count
        )
    }

    private func persistApplications() {
        guard let data = try? JSONEncoder().encode(applications) else { return }
        UserDefaults.standard.set(data, forKey: applicationsKey)
    }

    private func persistFeedback() {
        guard let data = try? JSONEncoder().encode(Array(feedbackByJobID.values)) else { return }
        UserDefaults.standard.set(data, forKey: feedbackKey)
    }

    private func persistResumeVersions() {
        guard let data = try? JSONEncoder().encode(resumeVersions) else { return }
        UserDefaults.standard.set(data, forKey: resumeVersionsKey)
    }

    private func persistSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    private func persistAnalytics() {
        guard let data = try? JSONEncoder().encode(analyticsEvents) else { return }
        UserDefaults.standard.set(data, forKey: analyticsKey)
    }

    private func scheduleAnalyticsPersist() {
        let eventsSnapshot = analyticsEvents
        let key = analyticsKey

        analyticsPersistTask?.cancel()
        analyticsPersistTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled,
                  let data = try? JSONEncoder().encode(eventsSnapshot) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

extension Job {
    static func loadSeedJobs() -> [Job] {
        guard let url = Bundle.main.url(forResource: "SeedJobs", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return fallbackSeed
        }

        let jobs = decodeSeedJobs(from: data, requireRecentVerification: true)
        return jobs.isEmpty ? fallbackSeed : jobs
    }

    static func decodeSeedJobs(from data: Data, requireRecentVerification: Bool, maxAgeHours: Int = 36) -> [Job] {
        decodeSeedJobRecords(
            from: data,
            requireRecentVerification: requireRecentVerification,
            maxAgeHours: maxAgeHours
        )
            .map(\.job)
    }

    static func decodeSeedJobRecords(from data: Data, requireRecentVerification: Bool, maxAgeHours: Int = 36) -> [SeedJob] {
        guard let decoded = try? JSONDecoder().decode([SeedJob].self, from: data) else {
            return []
        }

        return decoded.filter { seedJob in
            !requireRecentVerification || seedJob.hasRecentLiveVerification(maxAgeHours: maxAgeHours)
        }
    }

    static let fallbackSeed: [Job] = []
}
