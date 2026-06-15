import Foundation

enum ExperienceLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case internship = "Internship"
    case entry = "Entry Level"
    case mid = "Mid Level"
    case senior = "Senior"

    var id: String { rawValue }
}

enum ResumeTemplate: String, CaseIterable, Identifiable, Codable, Sendable {
    case atsClassic = "ATS Classic"
    case modernSnapshot = "Modern Snapshot"
    case operations = "Operations"
    case sales = "Sales"
    case customerSuccess = "Customer Success"
    case healthcare = "Healthcare"
    case student = "Student"
    case fieldWork = "Field Work"
    case creative = "Creative"

    var id: String { rawValue }

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .atsClassic: return "Plain format for job portals"
        case .modernSnapshot: return "Concise one-page profile"
        case .operations: return "Process, logistics, and execution"
        case .sales: return "Pipeline, accounts, and revenue"
        case .customerSuccess: return "Support, retention, and CRM"
        case .healthcare: return "Patient, care, and compliance"
        case .student: return "Education, projects, and internships"
        case .fieldWork: return "Hands-on, safety, and reliability"
        case .creative: return "Portfolio, campaigns, and content"
        }
    }

    var systemImage: String {
        switch self {
        case .atsClassic: return "doc.text"
        case .modernSnapshot: return "rectangle.grid.1x2"
        case .operations: return "shippingbox"
        case .sales: return "chart.line.uptrend.xyaxis"
        case .customerSuccess: return "person.2.wave.2"
        case .healthcare: return "cross.case"
        case .student: return "graduationcap"
        case .fieldWork: return "wrench.and.screwdriver"
        case .creative: return "paintpalette"
        }
    }
}

enum ResumeRegion: String, CaseIterable, Identifiable, Codable, Sendable {
    case northAmerica = "North America"
    case australia = "Australia"
    case unitedKingdom = "United Kingdom"
    case europe = "Europe"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .northAmerica: return "US / Canada"
        case .australia: return "Australia"
        case .unitedKingdom: return "UK"
        case .europe: return "Europe"
        }
    }

    var guidance: String {
        switch self {
        case .northAmerica:
            return "One-page ATS resume, no photo, measurable achievements, clear skills section."
        case .australia:
            return "Clear work rights, concise career summary, local availability, and practical experience."
        case .unitedKingdom:
            return "CV-style summary, key achievements, notice period or work rights when relevant."
        case .europe:
            return "Country-aware CV, language ability, work authorization, and role-specific credentials."
        }
    }

    var resumeSectionTitle: String {
        switch self {
        case .northAmerica: return "WORK AUTHORIZATION / TARGET MARKET"
        case .australia: return "AUSTRALIA WORK RIGHTS"
        case .unitedKingdom: return "UK WORK RIGHTS"
        case .europe: return "EUROPE WORK RIGHTS + LANGUAGES"
        }
    }
}

enum TargetCountry: String, CaseIterable, Identifiable, Codable, Sendable {
    case unitedStates = "United States"
    case canada = "Canada"
    case unitedKingdom = "United Kingdom"
    case germany = "Germany"
    case france = "France"
    case netherlands = "Netherlands"
    case ireland = "Ireland"
    case spain = "Spain"
    case sweden = "Sweden"
    case australia = "Australia"

    var id: String { rawValue }

    var region: ResumeRegion {
        switch self {
        case .unitedStates, .canada:
            return .northAmerica
        case .unitedKingdom:
            return .unitedKingdom
        case .australia:
            return .australia
        case .germany, .france, .netherlands, .ireland, .spain, .sweden:
            return .europe
        }
    }

    var shortTitle: String {
        switch self {
        case .unitedStates: return "US"
        case .canada: return "Canada"
        case .unitedKingdom: return "UK"
        case .germany: return "Germany"
        case .france: return "France"
        case .netherlands: return "Netherlands"
        case .ireland: return "Ireland"
        case .spain: return "Spain"
        case .sweden: return "Sweden"
        case .australia: return "Australia"
        }
    }

    var locationSignals: [String] {
        switch self {
        case .unitedStates:
            return [" united states ", " usa ", " us ", " new york ", " san francisco ", " los angeles ", " chicago ", " dallas ", " seattle ", " boston ", " austin ", " california ", " texas "]
        case .canada:
            return [" canada ", " toronto ", " vancouver ", " montreal ", " ottawa ", " calgary ", " waterloo ", " british columbia ", " ontario ", " quebec "]
        case .unitedKingdom:
            return [" united kingdom ", " uk ", " london ", " manchester ", " birmingham ", " edinburgh ", " leeds ", " bristol ", " glasgow "]
        case .germany:
            return [" germany ", " deutschland ", " berlin ", " munich ", " münchen ", " hamburg ", " frankfurt ", " cologne ", " köln "]
        case .france:
            return [" france ", " paris ", " lyon ", " toulouse ", " lille ", " marseille ", " nantes "]
        case .netherlands:
            return [" netherlands ", " holland ", " amsterdam ", " rotterdam ", " eindhoven ", " utrecht ", " the hague "]
        case .ireland:
            return [" ireland ", " dublin ", " cork ", " galway ", " limerick "]
        case .spain:
            return [" spain ", " madrid ", " barcelona ", " valencia ", " malaga ", " sevilla ", " seville "]
        case .sweden:
            return [" sweden ", " stockholm ", " gothenburg ", " göteborg ", " malmo ", " malmö ", " uppsala "]
        case .australia:
            return [" australia ", " sydney ", " melbourne ", " brisbane ", " perth ", " adelaide ", " canberra ", " gold coast "]
        }
    }

    var languageExpectation: String {
        switch self {
        case .unitedStates, .canada, .unitedKingdom, .ireland, .australia:
            return "English C1"
        case .germany:
            return "English C1, German B1/B2 when customer-facing"
        case .france:
            return "English C1, French B1/B2 for most local roles"
        case .netherlands:
            return "English C1, Dutch helpful for local/customer roles"
        case .spain:
            return "English C1, Spanish B1/B2 for most local roles"
        case .sweden:
            return "English C1, Swedish helpful for local/public roles"
        }
    }
}

extension ResumeRegion {
    var defaultTargetCountry: TargetCountry {
        switch self {
        case .northAmerica: return .unitedStates
        case .australia: return .australia
        case .unitedKingdom: return .unitedKingdom
        case .europe: return .germany
        }
    }
}

enum WorkAuthorizationStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case unknown = "Not sure yet"
    case noSponsorshipNeeded = "No sponsorship needed"
    case needsSponsorship = "Needs sponsorship"
    case studentOrGraduate = "Student / graduate route"
    case openWorkPermit = "Open work permit"
    case permanentResidentOrCitizen = "Citizen / PR / settled"
    case workingHoliday = "Working holiday"
    case euEeaCitizen = "EU / EEA citizen"

    var id: String { rawValue }

    static func inferred(from text: String) -> WorkAuthorizationStatus {
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.isEmpty || lower == "no preference" { return .unknown }
        if lower.contains("opt") || lower.contains("graduate") || lower.contains("student") || lower.contains("学生") || lower.contains("毕业") {
            return .studentOrGraduate
        }
        if lower.contains("open work") || lower.contains("开放工签") {
            return .openWorkPermit
        }
        if lower.contains("working holiday") || lower.contains("打工度假") {
            return .workingHoliday
        }
        if lower.contains("no sponsorship") || lower.contains("无需赞助") || lower.contains("right to work") || lower.contains("work rights") {
            return .noSponsorshipNeeded
        }
        if lower.contains("sponsor") || lower.contains("h-1b") || lower.contains("lmia") || lower.contains("skilled worker") || lower.contains("blue card") || lower.contains("赞助") || lower.contains("蓝卡") {
            return .needsSponsorship
        }
        if lower.range(of: #"\b(pr|permanent resident|settled|citizen)\b"#, options: .regularExpression) != nil || lower.contains("公民") || lower.contains("永居") {
            return .permanentResidentOrCitizen
        }
        if lower.range(of: #"\b(eu|eea)\b"#, options: .regularExpression) != nil || lower.contains("欧盟") {
            return .euEeaCitizen
        }
        return .unknown
    }
}

enum ResumeExportFormat: String, CaseIterable, Identifiable, Sendable {
    case txt = "ATS TXT"
    case pdf = "PDF"
    case word = "Word RTF"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .txt: return "txt"
        case .pdf: return "pdf"
        case .word: return "rtf"
        }
    }

    var systemImage: String {
        switch self {
        case .txt: return "doc.plaintext"
        case .pdf: return "doc.richtext"
        case .word: return "doc.text"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "System"
    case english = "English"
    case chinese = "Chinese"
    case korean = "Korean"
    case japanese = "Japanese"
    case french = "French"
    case german = "German"
    case russian = "Russian"
    case hindi = "Hindi"
    case swedish = "Swedish"
    case danish = "Danish"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .chinese: return "中文"
        case .korean: return "한국어"
        case .japanese: return "日本語"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .russian: return "Русский"
        case .hindi: return "हिन्दी"
        case .swedish: return "Svenska"
        case .danish: return "Dansk"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .system: return Self.systemPreferred.localeIdentifier
        case .english: return "en"
        case .chinese: return "zh-Hans"
        case .korean: return "ko"
        case .japanese: return "ja"
        case .french: return "fr"
        case .german: return "de"
        case .russian: return "ru"
        case .hindi: return "hi"
        case .swedish: return "sv"
        case .danish: return "da"
        }
    }

    func localized(_ key: String) -> String {
        switch self {
        case .system:
            return Self.systemPreferred.localized(key)
        case .chinese:
            return Self.chineseStrings[key] ?? key
        case .english, .korean, .japanese, .french, .german, .russian, .hindi, .swedish, .danish:
            return key
        }
    }

    static var systemPreferred: AppLanguage {
        let identifiers = Locale.preferredLanguages.map { $0.lowercased() }
        if identifiers.contains(where: { $0.hasPrefix("zh") || $0.contains("hans") || $0.contains("hant") }) {
            return .chinese
        }
        if identifiers.contains(where: { $0.hasPrefix("ko") }) { return .korean }
        if identifiers.contains(where: { $0.hasPrefix("ja") }) { return .japanese }
        if identifiers.contains(where: { $0.hasPrefix("fr") }) { return .french }
        if identifiers.contains(where: { $0.hasPrefix("de") }) { return .german }
        if identifiers.contains(where: { $0.hasPrefix("ru") }) { return .russian }
        if identifiers.contains(where: { $0.hasPrefix("hi") }) { return .hindi }
        if identifiers.contains(where: { $0.hasPrefix("sv") }) { return .swedish }
        if identifiers.contains(where: { $0.hasPrefix("da") }) { return .danish }
        return .english
    }

    private static let chineseStrings: [String: String] = [
        "JobPilot Lite": "JobPilot Lite",
        "Build your job profile once, generate resumes from templates, match roles across industries, and track every follow-up.": "一次填写求职资料，按模板生成简历，并匹配跨行业职位。",
        "Save Profile & Show Matches": "保存资料并查看匹配",
        "Preview Resume": "预览简历",
        "Use Demo Profile": "使用演示资料",
        "Quick start": "快速开始",
        "Target": "目标",
        "Location": "地点",
        "Jobs": "职位",
        "Profile": "资料",
        "Matches": "匹配",
        "Save": "保存",
        "Search title, company, skill": "搜索职位、公司、技能",
        "Search any title, company, skill": "搜索任意职位、公司、技能",
        "Role, company, or skill": "职位、公司或技能",
        "Location or remote": "地点或远程",
        "Edit profile": "编辑资料",
        "Loading verified jobs": "正在加载已验证职位",
        "Preparing live roles and resume matches.": "正在准备真实职位和简历匹配。",
        "No verified jobs available": "暂无已验证职位",
        "The job feed is waiting for a fresh live verification run.": "职位源正在等待新的实时验证结果。",
        "No search results": "没有搜索结果",
        "Try a broader title, skill, company, or location.": "换一个更宽的职位、技能、公司或地点试试。",
        "Today": "今日",
        "All": "全部",
        "Strong": "强匹配",
        "Remote": "远程",
        "Entry": "初级",
        "Visa": "签证",
        "Salary": "薪资",
        "ATS-free": "免 ATS",
        "Contact": "联系人",
        "Apply link": "申请链接",
        "ATS-free direct apply": "免 ATS 直投",
        "Employer ATS required": "需要雇主 ATS",
        "Saved": "已保存",
        "Not listed": "未列出",
        "Strong Match": "强匹配",
        "Good Match": "较匹配",
        "Maybe": "可考虑",
        "Low Fit": "匹配较低",
        "Visa friendly": "签证友好",
        "Compensation": "薪酬",
        "Source": "来源",
        "Improve recommendations": "优化推荐",
        "Why your resume matches": "为什么你的简历匹配",
        "Role summary": "职位概述",
        "Requirements": "要求",
        "Skills": "技能",
        "Generate Resume & Apply": "生成简历并投递",
        "Save Job": "保存职位",
        "Apply method": "投递方式",
        "Application Kit": "投递材料",
        "ATS-friendly resume": "ATS 友好简历",
        "Generated resume": "自动生成简历",
        "Edit the resume before applying": "投递前可以直接修改这份简历。",
        "Optimize ATS keywords": "优化 ATS 关键词",
        "Recruiter note": "招聘方留言",
        "The edited resume is attached below this note when you copy or email the application.": "复制或发送申请时，已编辑简历会自动附在这段留言下方。",
        "Apply from this app": "在软件内准备投递",
        "The official apply link opens when the employer requires their ATS form. Your resume and note stay saved here.": "如果雇主要求填写官方 ATS 表单，会打开已验证申请链接；你的简历和留言会保存在这里。",
        "Open Verified Apply Link": "打开已验证投递链接",
        "JobPilot keeps the application inside this app when possible. It prepares the resume, profile fields, and screening answers before you confirm the final submission.": "JobPilot 会尽量把投递留在本软件内完成，并在你确认提交前准备好简历、资料字段和筛选题答案。",
        "Open In-App Apply Workspace": "打开软件内投递工作台",
        "Send ATS-Free Direct Application": "发送免 ATS 直投申请",
        "Open employer ATS backup": "打开雇主 ATS 备用入口",
        "Open ATS Helper": "打开 ATS 辅助工作台",
        "This job has no verified direct apply channel. JobPilot cannot fully bypass this employer ATS.": "这条岗位没有已验证直投通道。JobPilot 不能完全绕过这个雇主 ATS。",
        "Application workspace ready": "投递工作台已准备好",
        "No direct apply channel found": "未找到直投通道",
        "Mail draft opened": "邮件草稿已打开",
        "ATS-free application sent": "免 ATS 直投申请已发送",
        "Mail draft saved": "邮件草稿已保存",
        "Direct application cancelled": "直投已取消",
        "Mail unavailable; application copied": "邮件不可用，已复制申请材料",
        "Copied application autofill packet": "已复制投递自动填写包",
        "Autofill coverage": "自动填写覆盖",
        "Autofill packet": "自动填写包",
        "Copy autofill packet": "复制自动填写包",
        "Prepared profile fields": "已准备资料字段",
        "Prepared screening answers": "已准备筛选题答案",
        "Apply Workspace": "投递工作台",
        "Apply link unavailable": "申请链接不可用",
        "Use the autofill packet below to continue.": "可使用下方自动填写包继续投递。",
        "Screening answers": "筛选题答案",
        "Generated materials": "已生成材料",
        "Direct apply channel ready": "直投通道已就绪",
        "Standard ATS adapter ready": "标准 ATS 适配器已就绪",
        "Embedded ATS adapter ready": "内嵌 ATS 适配器已就绪",
        "Account-heavy adapter ready": "重账号 ATS 适配器已就绪",
        "Universal adapter ready": "通用适配器已就绪",
        "No ATS": "无 ATS",
        "Low friction": "低摩擦",
        "Medium friction": "中等摩擦",
        "High friction": "高摩擦",
        "Unknown friction": "未知摩擦",
        "In-app application page": "软件内申请页",
        "No employer ATS form": "无需雇主 ATS 表单",
        "In-app email composer": "软件内邮件编辑器",
        "Resume attached": "已附上简历",
        "Resume upload files": "简历上传文件",
        "Profile autofill packet": "资料自动填写包",
        "Screening answer bank": "筛选题答案库",
        "Final user confirmation": "用户最终确认",
        "Copy-safe formatted answers": "可安全复制的格式化答案",
        "Account setup helper": "账号创建辅助",
        "Only use direct apply when the employer provided this channel": "只有雇主提供直投通道时才使用直投",
        "Review custom questions before submitting": "提交前检查自定义问题",
        "Some fields may still require manual confirmation": "部分字段仍可能需要手动确认",
        "This ATS may require login or account creation": "这个 ATS 可能需要登录或创建账号",
        "Review every parsed resume field before submitting": "提交前检查每个被解析的简历字段",
        "Universal mode cannot guarantee every field is detectable": "通用模式不能保证识别每一个字段",
        "Email Recruiter": "邮件联系招聘方",
        "Save Resume": "保存简历",
        "Copy Resume": "复制简历",
        "Copy Application": "复制申请材料",
        "Build Upload Files": "生成可上传文件",
        "Generated materials saved": "已保存投递材料",
        "Copied resume": "已复制简历",
        "Copied application": "已复制申请材料",
        "Files ready": "文件已生成",
        "ATS keywords updated": "已优化 ATS 关键词",
        "Real apply link": "真实投递链接",
        "Use this page to generate, edit, save, and submit job-specific materials.": "在这里生成、修改、保存并提交岗位定制材料。",
        "ATS-free direct channel": "免 ATS 直投通道",
        "Direct": "直投",
        "Use this page to generate, edit, and send a direct application without the employer ATS.": "在这里生成、修改并发送直投申请，不经过雇主 ATS。",
        "Use this page to generate, edit, and prepare materials. This employer still requires its ATS for the final application.": "在这里生成、修改并准备材料；最终申请仍需要经过雇主 ATS。",
        "This job has a verified direct apply channel. JobPilot can prepare the resume and open an in-app email composer without sending the user through the employer ATS.": "这条岗位有已验证直投通道。JobPilot 可以准备简历并打开软件内邮件编辑器，不让用户进入雇主 ATS。",
        "This employer still requires its ATS. JobPilot cannot fully bypass it, but it keeps the page inside the app and prepares every field before final confirmation.": "这个雇主仍要求使用 ATS。JobPilot 不能完全绕过它，但会把页面留在软件内，并在最终确认前准备好字段。",
        "This employer still requires account-based ATS steps. JobPilot cannot bypass login, account creation, or employer verification screens.": "这个雇主仍要求账号型 ATS 步骤。JobPilot 不能绕过登录、创建账号或雇主验证页面。",
        "No verified direct apply channel is available. JobPilot can only assist with the employer page and prepared answers.": "当前没有已验证直投通道。JobPilot 只能辅助打开雇主页面并准备答案。",
        "Open Apply Link": "打开申请链接",
        "Subject": "主题",
        "Copy": "复制",
        "Email": "邮件",
        "Application": "申请",
        "Application Strategy": "投递作战",
        "Readiness": "准备度",
        "Market & authorization": "市场与工签",
        "Auto resume template": "自动简历模板",
        "Resume focus": "简历重点",
        "Missing keywords": "缺失关键词",
        "Next actions": "下一步动作",
        "Interview prep": "面试准备",
        "Save Targeted Resume": "保存定制简历",
        "Copy Plan": "复制计划",
        "Targeted resume saved": "已保存定制简历",
        "No missing keywords": "关键词覆盖良好",
        "Copied application plan": "已复制投递计划",
        "Ready to apply after a final review": "最终检查后即可投递",
        "Good fit, improve the resume before applying": "匹配不错，投递前先优化简历",
        "Useful lead, but fix gaps first": "值得保留，但先补齐差距",
        "Low readiness, save only if strategically important": "准备度较低，仅在战略重要时保留",
        "Save a targeted resume version for this role": "保存一个针对该岗位的简历版本",
        "Mirror the top missing keywords in 2-3 bullets": "把最重要的缺失关键词写进 2-3 条经历要点",
        "Send the ATS-free direct application from JobPilot": "从 JobPilot 发送免 ATS 直投申请",
        "Use the ATS helper and keep a follow-up date": "使用 ATS 辅助工作台，并设置后续跟进日期",
        "Use the apply link and keep a follow-up date": "使用申请链接，并设置后续跟进日期",
        "Send a concise recruiter message after applying": "投递后发送一条简洁的招聘方消息",
        "Check the employer's sponsorship policy before spending more time": "投入更多时间前，先确认雇主是否支持签证赞助",
        "Rewrite the resume before applying": "投递前先重写简历重点",
        "Done": "完成",
        "No Applications Yet": "还没有申请",
        "Save a role from Matches to start tracking.": "从匹配页保存职位后即可继续查看。",
        "Status": "状态",
        "Notes": "备注",
        "Follow up": "跟进",
        "Next: tailor resume and apply": "下一步：定制简历并申请",
        "Next: add follow-up date": "下一步：添加跟进日期",
        "Next: send follow-up today": "下一步：今天发送跟进",
        "Next: follow up": "下一步：跟进",
        "Next: monitor reply or prepare interview notes": "下一步：关注回复或准备面试记录",
        "Next: prepare STAR answers": "下一步：准备 STAR 回答",
        "Closed: learn and move on": "已结束：复盘并继续",
        "Next: compare offer details": "下一步：比较 offer 细节",
        "Continue application": "继续投递",
        "Apply": "投递",
        "Draft not generated yet": "尚未生成草稿",
        "Apply link only": "仅申请链接",
        "Role found": "找到职位",
        "Copy Only": "仅复制",
        "Source check": "来源检查",
        "A recruiting contact is attached to this role. Review the draft before sending and keep the application status updated.": "该职位带有招聘联系人。发送前请检查草稿，并保持申请状态更新。",
        "Save Profile": "保存资料",
        "Settings": "设置",
        "Reset all local MVP data?": "重置所有本地 MVP 数据？",
        "Reset": "重置",
        "Cancel": "取消",
        "Registration profile": "注册资料",
        "Essential profile": "必要资料",
        "Only the fields needed for matching and automatic job-specific resumes.": "只填写用于匹配和自动生成岗位定制简历的必要信息。",
        "Basic information": "基本信息",
        "Full name": "姓名",
        "Phone": "电话",
        "Current city": "当前城市",
        "Target role": "目标职位",
        "Preferred city": "偏好城市",
        "Preferred city or region": "想工作的城市或地区",
        "Email address": "邮箱",
        "Preferred location": "偏好地点",
        "Work mode": "工作模式",
        "Opportunity type": "机会类型",
        "Experience level": "经验级别",
        "Education and skills": "学历和技能",
        "Level": "级别",
        "Resume region": "简历地区",
        "Skills, separated by commas": "技能，用逗号分隔",
        "Resume history": "简历经历",
        "Professional summary": "职业概述",
        "Work history, one role or bullet per line": "工作经历，每行一个职位或要点",
        "Recent experience summary": "近期经历概述",
        "Project, achievement, or measurable result": "项目、成就或可量化结果",
        "Education": "教育经历",
        "Certifications": "证书",
        "Portfolio URL": "作品集链接",
        "Authorized to work answer": "工作权利回答",
        "Sponsorship answer": "签证赞助回答",
        "Location answer": "地点回答",
        "Start date answer": "入职时间回答",
        "Salary answer": "薪资回答",
        "Why this role answer": "为什么申请该岗位",
        "Certifications, licenses, or training": "证书、执照或培训",
        "LinkedIn, portfolio, or website": "LinkedIn、作品集或网站",
        "Visa preference": "签证偏好",
        "Languages": "语言",
        "Operations Associate": "运营专员",
        "Customer Support": "客户支持",
        "Sales Representative": "销售代表",
        "Retail Associate": "零售店员",
        "Healthcare Coordinator": "医疗协调员",
        "Marketing Associate": "市场专员",
        "Data Analyst": "数据分析师",
        "Software Engineer": "软件工程师",
        "Product Manager": "产品经理",
        "Finance Analyst": "财务分析师",
        "Marketing": "市场",
        "Visa Sponsorship": "签证赞助",
        "HR Coordinator": "人力资源协调员",
        "Warehouse Associate": "仓库专员",
        "Teacher": "教师",
        "New York": "纽约",
        "Los Angeles": "洛杉矶",
        "Chicago": "芝加哥",
        "Dallas": "达拉斯",
        "San Francisco": "旧金山",
        "Toronto": "多伦多",
        "Resume format": "简历格式",
        "Pick the resume layout that best fits the role you are applying to.": "选择最适合目标职位的简历版式。",
        "Job Search Score": "求职分数",
        "Improve the score by completing your profile, applying to strong matches, and clearing follow-ups.": "完善资料、申请强匹配职位并处理跟进，可提升分数。",
        "Pipeline": "流程",
        "Invite Test Users": "邀请测试用户",
        "Share the MVP with your first cohort": "分享给第一批测试用户",
        "Send Feedback": "发送反馈",
        "Open an email with device and app context": "打开带有设备和应用上下文的邮件",
        "Privacy": "隐私",
        "Local MVP data and user control": "本地 MVP 数据与用户控制",
        "Resume Builder": "简历生成器",
        "Choose a format, generate, and copy your resume": "选择格式、生成并复制简历",
        "Reset Local Data": "重置本地数据",
        "Clear profile, tracker, and local metrics": "清除资料、已保存职位和本地指标",
        "Language": "语言",
        "App language": "应用语言",
        "System": "跟随系统",
        "English": "英语",
        "Chinese": "中文",
        "Korean": "韩语",
        "Japanese": "日语",
        "French": "法语",
        "German": "德语",
        "Russian": "俄语",
        "Hindi": "印地语",
        "Swedish": "瑞典语",
        "Danish": "丹麦语",
        "English is the default language for this MVP. The selected language is saved locally and updates the app interface immediately.": "当前版本默认使用中文。选择的语言会保存在本地，并立即更新应用界面。",
        "Account & Security Center": "账号与安全中心",
        "Profile identity, privacy, and login controls": "资料身份、隐私和登录控制",
        "Notifications & Reminders": "通知与提醒",
        "Matches, follow-ups, interviews, and security alerts": "匹配、跟进、面试和安全提醒",
        "General Settings": "通用设置",
        "Message Settings": "消息设置",
        "Tone, draft behavior, and message content": "语气、草稿行为和消息内容",
        "Account": "账号",
        "Name": "姓名",
        "Not set": "未设置",
        "Security": "安全",
        "Biometric unlock": "生物识别解锁",
        "Hide personal data previews": "隐藏个人数据预览",
        "Security alerts": "安全提醒",
        "Account & Security": "账号与安全",
        "Password login, two-factor authentication, and account deletion should be connected when the real account backend is added.": "接入真实账号后端后，应补上密码登录、双重验证和账号删除。",
        "Notifications": "通知",
        "Daily match digest": "每日匹配摘要",
        "Digest times": "摘要时间",
        "8:30 PM and 11:30 PM": "晚上 8:30 和 11:30",
        "Notification permission": "通知权限",
        "Checking": "正在检查",
        "Not requested": "未请求",
        "Allowed": "已允许",
        "Denied in iOS Settings": "已在 iOS 设置中关闭",
        "Reminders": "提醒",
        "Follow-up reminders": "跟进提醒",
        "Interview reminders": "面试提醒",
        "These switches are stored locally now. Push notification permissions and scheduling can be connected after the MVP validates demand.": "这些开关目前存储在本地。MVP 验证需求后，可接入推送权限和提醒调度。",
        "Match digests are scheduled on this iPhone in its current time zone. No server push worker is required.": "匹配摘要会按这台 iPhone 当前时区在本机调度，不需要服务器推送任务。",
        "your target role": "目标岗位",
        "General": "通用",
        "Experience": "体验",
        "Compact job cards": "紧凑职位卡片",
        "Open apply links externally": "在外部打开申请链接",
        "Default language is English. The selected app language updates supported interface strings immediately.": "默认语言已改为中文。选择应用语言后，已支持的界面文案会立即更新。",
        "Messages": "消息",
        "Drafts": "草稿",
        "Auto-save message drafts": "自动保存消息草稿",
        "Include resume summary": "包含简历摘要",
        "Include contact info": "包含联系方式",
        "Tone": "语气",
        "Message tone": "消息语气",
        "Message generation is template-based in this MVP, so these preferences prepare the product for safer personalization without adding AI API cost yet.": "此 MVP 的消息生成基于模板，这些偏好设置用于在不增加 AI API 成本的情况下准备更安全的个性化。",
        "Local MVP storage": "本地 MVP 存储",
        "This prototype stores your profile, saved applications, follow-up dates, and local usage counters on this device.": "此原型会把你的资料、已保存申请、跟进日期和本地使用计数存储在本设备上。",
        "No AI processing": "无 AI 处理",
        "The current version uses templates and local matching rules. It does not send resume content to an AI API.": "当前版本使用模板和本地匹配规则，不会把简历内容发送到 AI API。",
        "No automatic submission": "不会自动代投",
        "Application materials are generated for review. You choose whether to copy, email, or open an apply link.": "投递材料会先生成给你检查。是否复制、发邮件或打开申请链接由你决定。",
        "User control": "用户控制",
        "You can reset local profile, tracker, and metric data from the Profile tab.": "你可以在资料页重置本地资料、已保存职位和指标数据。",
        "Before public launch": "公开发布前",
        "Replace this MVP text with a lawyer-reviewed privacy policy, support address, data deletion path, and App Store privacy details.": "公开发布前，请替换为律师审阅后的隐私政策、支持邮箱、数据删除路径和 App Store 隐私说明。",
        "Resume Studio": "简历工作台",
        "Target market": "目标市场",
        "Market readiness": "市场准备度",
        "Overseas job assistant": "海外求职助手",
        "Do this first": "先做这一步",
        "Helpful next steps": "有帮助的下一步",
        "Fix before applying": "投递前先修正",
        "Country-specific checks": "国家专项检查",
        "Country rules": "国家规则",
        "Resume rules": "简历规则",
        "Work authorization checks": "工作权利检查",
        "Profile gaps": "资料缺口",
        "Market next actions": "市场下一步",
        "Save market resume": "保存市场专用简历",
        "Market resume saved": "已保存市场简历",
        "Copy work-rights line": "复制工作权利说明",
        "Copied work-rights line": "已复制工作权利说明",
        "Copy resume fixes": "复制简历修改清单",
        "Copied resume fixes": "已复制简历修改清单",
        "Copy market checklist": "复制市场清单",
        "Copied market checklist": "已复制市场清单",
        "Job-tailored resume": "岗位定制简历",
        "Target job title": "目标职位名称",
        "Company, optional": "公司，可选",
        "Paste job description for keyword targeting": "粘贴职位描述以提取关键词",
        "Generate": "生成",
        "Rewrite": "改写",
        "ATS score": "ATS 分数",
        "Keywords": "关键词",
        "Words": "字数",
        "Missing": "缺失",
        "Version name": "版本名称",
        "Build Export Files": "生成导出文件",
        "Saved versions": "已保存版本",
        "Saved resume versions will appear here.": "已保存的简历版本会显示在这里。",
        "ATS": "ATS",
        "Any": "不限",
        "On-site": "线下",
        "Hybrid": "混合办公",
        "Full-time": "全职",
        "Part-time": "兼职",
        "Contract": "合同",
        "Internship": "实习",
        "Entry Level": "初级",
        "Mid Level": "中级",
        "Senior": "高级",
        "ATS Classic": "ATS 经典",
        "Modern Snapshot": "现代摘要",
        "Operations": "运营",
        "Sales": "销售",
        "Customer Success": "客户成功",
        "Healthcare": "医疗健康",
        "Student": "学生",
        "Field Work": "现场工作",
        "Creative": "创意",
        "Plain format for job portals": "适合招聘网站的纯文本格式",
        "Concise one-page profile": "简洁的一页式资料",
        "Process, logistics, and execution": "流程、物流与执行",
        "Pipeline, accounts, and revenue": "销售管道、客户与收入",
        "Support, retention, and CRM": "支持、留存与 CRM",
        "Patient, care, and compliance": "患者、护理与合规",
        "Education, projects, and internships": "教育、项目与实习",
        "Hands-on, safety, and reliability": "动手能力、安全与可靠性",
        "Portfolio, campaigns, and content": "作品集、活动与内容",
        "North America": "北美",
        "Australia": "澳洲",
        "United States": "美国",
        "Canada": "加拿大",
        "United Kingdom": "英国",
        "Germany": "德国",
        "France": "法国",
        "Netherlands": "荷兰",
        "Ireland": "爱尔兰",
        "Spain": "西班牙",
        "Sweden": "瑞典",
        "Europe": "欧洲",
        "US / Canada": "美国 / 加拿大",
        "UK": "英国",
        "Target country": "目标国家",
        "Work authorization": "工作权利",
        "Not sure yet": "还不确定",
        "No sponsorship needed": "无需雇主赞助",
        "Needs sponsorship": "需要雇主赞助",
        "Student / graduate route": "学生/毕业生路径",
        "Open work permit": "开放工签",
        "Citizen / PR / settled": "公民/永居/定居身份",
        "Working holiday": "打工度假",
        "EU / EEA citizen": "欧盟/欧洲经济区公民",
        "One-page ATS resume, no photo, measurable achievements, clear skills section.": "一页式 ATS 简历，无照片，突出可量化成果和清晰技能区。",
        "Clear work rights, concise career summary, local availability, and practical experience.": "清楚说明工作权利、简洁职业摘要、本地可用性和实践经验。",
        "CV-style summary, key achievements, notice period or work rights when relevant.": "CV 风格摘要，突出关键成果，必要时说明通知期或工作权利。",
        "Country-aware CV, language ability, work authorization, and role-specific credentials.": "按国家习惯组织 CV，强调语言能力、工作授权和岗位相关证书。",
        "Professional": "专业",
        "Concise": "简洁",
        "Warm": "亲和",
        "Applied": "已申请",
        "Follow Up": "跟进",
        "Interview": "面试",
        "Rejected": "已拒绝",
        "Offer": "Offer",
        "Not relevant": "不相关",
        "Too senior": "级别太高",
        "Wrong location": "地点不合适",
        "Wrong industry": "行业不合适",
        "Salary too low": "薪资太低",
        "Already applied": "已经申请",
        "Contact information is visible": "联系方式清晰可见",
        "Add email and phone near the top": "在顶部添加邮箱和电话",
        "Summary/objective section is present": "已有摘要/目标区",
        "Skills section is easy to scan": "技能区易于浏览",
        "Experience section is present": "已有经历区",
        "Education section is present": "已有教育区",
        "Keyword coverage is strong for the target role": "目标岗位关键词覆盖较强",
        "Add more exact terms from the job description": "加入更多职位描述中的精确用词",
        "Length is within a practical ATS range": "长度处于实用 ATS 范围内",
        "Resume is short; add measurable experience bullets": "简历偏短；补充可量化经历要点",
        "Resume is long; trim older or unrelated details": "简历偏长；删减较旧或无关内容",
        "Too many separator-heavy lines can reduce scan quality": "分隔符过多可能影响扫描质量",
        "Generate or paste a resume draft to run the ATS check.": "生成或粘贴简历草稿后运行 ATS 检查。"
    ]
}

enum MessageTone: String, CaseIterable, Identifiable, Codable, Sendable {
    case professional = "Professional"
    case concise = "Concise"
    case warm = "Warm"

    var id: String { rawValue }
}

enum WorkModePreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case any = "Any"
    case remote = "Remote"
    case hybrid = "Hybrid"
    case onSite = "On-site"

    var id: String { rawValue }
}

enum OpportunityType: String, CaseIterable, Identifiable, Codable, Sendable {
    case any = "Any"
    case internship = "Internship"
    case fullTime = "Full-time"
    case partTime = "Part-time"
    case contract = "Contract"

    var id: String { rawValue }
}

enum ApplicationStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case saved = "Saved"
    case applied = "Applied"
    case followUp = "Follow Up"
    case interview = "Interview"
    case rejected = "Rejected"
    case offer = "Offer"

    var id: String { rawValue }
}

enum JobFeedbackReason: String, CaseIterable, Identifiable, Codable, Sendable {
    case notRelevant = "Not relevant"
    case tooSenior = "Too senior"
    case wrongLocation = "Wrong location"
    case wrongIndustry = "Wrong industry"
    case salaryTooLow = "Salary too low"
    case alreadyApplied = "Already applied"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .notRelevant: return "xmark.circle"
        case .tooSenior: return "arrow.up.forward"
        case .wrongLocation: return "mappin.slash"
        case .wrongIndustry: return "building.2"
        case .salaryTooLow: return "dollarsign.arrow.circlepath"
        case .alreadyApplied: return "checkmark.circle"
        }
    }

    var exactPenalty: Int {
        switch self {
        case .notRelevant: return 70
        case .tooSenior: return 45
        case .wrongLocation: return 40
        case .wrongIndustry: return 40
        case .salaryTooLow: return 30
        case .alreadyApplied: return 80
        }
    }
}

struct CandidateProfile: Codable, Equatable, Sendable {
    var fullName = ""
    var email = ""
    var phone = ""
    var city = ""
    var targetTitle = "Operations Associate"
    var preferredLocation = ""
    var workModePreference: WorkModePreference = .any
    var opportunityType: OpportunityType = .fullTime
    var experienceLevel: ExperienceLevel = .entry
    var visaPreference = "No preference"
    var workAuthorizationStatus: WorkAuthorizationStatus = .unknown
    var languages = "English"
    var skills: [String] = ["Communication", "Excel", "Customer Service"]
    var professionalSummary = ""
    var education = ""
    var workHistory = ""
    var recentExperience = ""
    var projectHighlight = ""
    var certifications = ""
    var portfolioURL = ""
    var resumeTemplate: ResumeTemplate = .modernSnapshot
    var resumeRegion: ResumeRegion = .northAmerica
    var targetCountry: TargetCountry = .unitedStates

    init(
        fullName: String = "",
        email: String = "",
        phone: String = "",
        city: String = "",
        targetTitle: String = "Operations Associate",
        preferredLocation: String = "",
        workModePreference: WorkModePreference = .any,
        opportunityType: OpportunityType = .fullTime,
        experienceLevel: ExperienceLevel = .entry,
        visaPreference: String = "No preference",
        workAuthorizationStatus: WorkAuthorizationStatus = .unknown,
        languages: String = "English",
        skills: [String] = ["Communication", "Excel", "Customer Service"],
        professionalSummary: String = "",
        education: String = "",
        workHistory: String = "",
        recentExperience: String = "",
        projectHighlight: String = "",
        certifications: String = "",
        portfolioURL: String = "",
        resumeTemplate: ResumeTemplate = .modernSnapshot,
        resumeRegion: ResumeRegion = .northAmerica,
        targetCountry: TargetCountry = .unitedStates
    ) {
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.city = city
        self.targetTitle = targetTitle
        self.preferredLocation = preferredLocation
        self.workModePreference = workModePreference
        self.opportunityType = opportunityType
        self.experienceLevel = experienceLevel
        self.visaPreference = visaPreference
        self.workAuthorizationStatus = workAuthorizationStatus
        self.languages = languages
        self.skills = skills
        self.professionalSummary = professionalSummary
        self.education = education
        self.workHistory = workHistory
        self.recentExperience = recentExperience
        self.projectHighlight = projectHighlight
        self.certifications = certifications
        self.portfolioURL = portfolioURL
        self.resumeTemplate = resumeTemplate
        self.resumeRegion = resumeRegion
        self.targetCountry = targetCountry.region == resumeRegion ? targetCountry : resumeRegion.defaultTargetCountry
    }

    enum CodingKeys: String, CodingKey {
        case fullName
        case email
        case phone
        case city
        case targetTitle
        case preferredLocation
        case workModePreference
        case opportunityType
        case experienceLevel
        case visaPreference
        case workAuthorizationStatus
        case languages
        case skills
        case professionalSummary
        case education
        case workHistory
        case recentExperience
        case projectHighlight
        case certifications
        case portfolioURL
        case resumeTemplate
        case resumeRegion
        case targetCountry
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        self.email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        self.city = try container.decodeIfPresent(String.self, forKey: .city) ?? ""
        self.targetTitle = try container.decodeIfPresent(String.self, forKey: .targetTitle) ?? "Operations Associate"
        self.preferredLocation = try container.decodeIfPresent(String.self, forKey: .preferredLocation) ?? ""
        self.workModePreference = try container.decodeIfPresent(WorkModePreference.self, forKey: .workModePreference) ?? Self.inferredWorkMode(from: self.preferredLocation)
        self.opportunityType = try container.decodeIfPresent(OpportunityType.self, forKey: .opportunityType) ?? .fullTime
        self.experienceLevel = try container.decodeIfPresent(ExperienceLevel.self, forKey: .experienceLevel) ?? .entry
        self.visaPreference = try container.decodeIfPresent(String.self, forKey: .visaPreference) ?? "No preference"
        self.workAuthorizationStatus = try container.decodeIfPresent(WorkAuthorizationStatus.self, forKey: .workAuthorizationStatus) ?? WorkAuthorizationStatus.inferred(from: self.visaPreference)
        self.languages = try container.decodeIfPresent(String.self, forKey: .languages) ?? "English"
        self.skills = try container.decodeIfPresent([String].self, forKey: .skills) ?? ["Communication", "Excel", "Customer Service"]
        self.professionalSummary = try container.decodeIfPresent(String.self, forKey: .professionalSummary) ?? ""
        self.education = try container.decodeIfPresent(String.self, forKey: .education) ?? ""
        self.workHistory = try container.decodeIfPresent(String.self, forKey: .workHistory) ?? ""
        self.recentExperience = try container.decodeIfPresent(String.self, forKey: .recentExperience) ?? ""
        self.projectHighlight = try container.decodeIfPresent(String.self, forKey: .projectHighlight) ?? ""
        self.certifications = try container.decodeIfPresent(String.self, forKey: .certifications) ?? ""
        self.portfolioURL = try container.decodeIfPresent(String.self, forKey: .portfolioURL) ?? ""
        self.resumeTemplate = try container.decodeIfPresent(ResumeTemplate.self, forKey: .resumeTemplate) ?? .modernSnapshot
        self.resumeRegion = try container.decodeIfPresent(ResumeRegion.self, forKey: .resumeRegion) ?? .northAmerica
        self.targetCountry = try container.decodeIfPresent(TargetCountry.self, forKey: .targetCountry) ?? self.resumeRegion.defaultTargetCountry
    }

    static func inferredWorkMode(from text: String) -> WorkModePreference {
        let lower = text.lowercased()
        if lower.contains("remote") || lower.contains("远程") { return .remote }
        if lower.contains("hybrid") || lower.contains("混合") { return .hybrid }
        if lower.contains("on-site") || lower.contains("onsite") || lower.contains("office") || lower.contains("线下") { return .onSite }
        return .any
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    var language: AppLanguage = .chinese
    var biometricUnlock = false
    var hidePersonalData = false
    var securityAlerts = true
    var dailyMatchDigest = true
    var followUpReminders = true
    var interviewReminders = true
    var compactJobCards = false
    var openApplyLinksExternally = true
    var autoSaveDrafts = true
    var includeResumeSummary = true
    var includeContactInfo = true
    var messageTone: MessageTone = .professional
}

enum JobApplyChannel: String, Sendable {
    case atsFreeEmail = "ATS-free direct apply"
    case employerATS = "Employer ATS required"
}

struct Job: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var company: String
    var title: String
    var city: String
    var remoteType: String
    var salary: String
    var tags: [String]
    var sourceURL: String
    var contactEmail: String?
    var summary: String
    var requirements: [String]
    var visaFriendly: Bool
    var postedDate: Date

    var directApplyAddress: String? {
        if let contactEmail,
           let email = Self.normalizedEmail(contactEmail) {
            return email
        }

        guard let url = URL(string: sourceURL),
              url.scheme?.lowercased() == "mailto" else {
            return nil
        }

        let rawAddress = sourceURL
            .dropFirst("mailto:".count)
            .split(separator: "?")
            .first
            .map(String.init) ?? ""
        return Self.normalizedEmail(rawAddress)
    }

    var canBypassEmployerATS: Bool {
        directApplyAddress != nil
    }

    var applyChannel: JobApplyChannel {
        canBypassEmployerATS ? .atsFreeEmail : .employerATS
    }

    private static func normalizedEmail(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"),
              trimmed.contains("."),
              !trimmed.contains(" ") else {
            return nil
        }
        return trimmed
    }
}

struct JobFeedConfig: Codable, Sendable {
    var remoteJobsURL: String
    var remoteJobIndexURL: String?
    var minimumLiveJobs: Int
    var startupMinimumLiveJobs: Int?
    var refreshIntervalHours: Int
    var prefetchSliceLimit: Int?

    var remoteURL: URL? {
        let trimmed = remoteJobsURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    var remoteIndexURL: URL? {
        let trimmed = (remoteJobIndexURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    var startupMinimum: Int {
        max(startupMinimumLiveJobs ?? 200, 1)
    }

    var sliceLimit: Int {
        max(prefetchSliceLimit ?? 3, 1)
    }

    static let fallback = JobFeedConfig(
        remoteJobsURL: "",
        remoteJobIndexURL: "",
        minimumLiveJobs: 12000,
        startupMinimumLiveJobs: 200,
        refreshIntervalHours: 24,
        prefetchSliceLimit: 3
    )

    static func load() -> JobFeedConfig {
        guard let url = Bundle.main.url(forResource: "JobFeedConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(JobFeedConfig.self, from: data) else {
            return fallback
        }

        return decoded
    }
}

struct JobFeedIndex: Codable, Sendable {
    var generatedAt: String?
    var liveJobsURL: String?
    var totalLiveJobs: Int?
    var startupJobs: Int?
    var featuredSliceIds: [String]?
    var slices: [JobFeedSliceDescriptor]
}

struct JobFeedSliceDescriptor: Codable, Identifiable, Sendable {
    var id: String
    var title: String
    var url: String
    var jobCount: Int
    var lastVerifiedAt: String?
    var category: String?
    var workMode: String?
    var opportunityType: String?
    var locations: [String]?
    var keywords: [String]?
}

struct SeedJob: Codable, Sendable {
    var id: String
    var company: String
    var title: String
    var city: String
    var remoteType: String
    var salary: String
    var tags: [String]
    var sourceURL: String
    var contactEmail: String?
    var summary: String
    var requirements: [String]?
    var visaFriendly: Bool
    var postedDaysAgo: Int
    var liveStatus: String?
    var lastVerifiedAt: String?
    var verifiedSourceURL: String?

    var job: Job {
        Job(
            id: UUID(uuidString: id) ?? UUID(),
            company: company,
            title: title,
            city: city,
            remoteType: remoteType,
            salary: salary,
            tags: tags,
            sourceURL: sourceURL,
            contactEmail: contactEmail,
            summary: summary,
            requirements: requirements ?? [],
            visaFriendly: visaFriendly,
            postedDate: Calendar.current.date(byAdding: .day, value: -postedDaysAgo, to: Date()) ?? Date()
        )
    }

    func hasRecentLiveVerification(maxAgeHours: Int) -> Bool {
        guard liveStatus == "live",
              let lastVerifiedAt,
              let verifiedAt = LiveVerificationDateParser.date(from: lastVerifiedAt) else {
            return false
        }

        let maxAge = TimeInterval(maxAgeHours * 3600)
        let age = Date().timeIntervalSince(verifiedAt)
        return age >= -300 && age <= maxAge
    }
}

private enum LiveVerificationDateParser {
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardFormatter = ISO8601DateFormatter()

    static func date(from value: String) -> Date? {
        fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value)
    }
}

struct JobMatch: Identifiable, Equatable, Sendable {
    var id: UUID { job.id }
    var job: Job
    var score: Int
    var reasons: [String]
    var searchText: String

    init(job: Job, score: Int, reasons: [String]) {
        self.job = job
        self.score = score
        self.reasons = reasons
        self.searchText = [
            job.title,
            job.company,
            job.city,
            job.remoteType,
            job.salary,
            job.tags.joined(separator: " "),
            job.summary,
            job.requirements.joined(separator: " ")
        ].joined(separator: " ").lowercased()
    }

    var label: String {
        switch score {
        case 80...100: return "Strong Match"
        case 60..<80: return "Good Match"
        case 40..<60: return "Maybe"
        default: return "Low Fit"
        }
    }
}

struct Application: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let jobID: UUID
    var status: ApplicationStatus
    var notes: String
    var draftSubject: String?
    var draftBody: String?
    var followUpDate: Date?
    var createdAt: Date
    var updatedAt: Date
}

struct JobFeedback: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { jobID }
    let jobID: UUID
    var reason: JobFeedbackReason
    var createdAt: Date
}

struct JobSearchHealth: Equatable, Sendable {
    var score: Int
    var profileScore: Int
    var pipelineScore: Int
    var followUpScore: Int
    var matchScore: Int
}

struct MarketScoreDimension: Identifiable, Equatable, Sendable {
    var id: String { title }
    var title: String
    var score: Int
    var detail: String
}

struct MarketReadinessPlan: Equatable, Sendable {
    var score: Int
    var marketTitle: String
    var summary: String
    var scoreDimensions: [MarketScoreDimension]
    var countryRules: [String]
    var resumeRules: [String]
    var authorizationChecks: [String]
    var priorityGaps: [String]
    var nextActions: [String]
}

struct GeneratedMessage: Equatable, Sendable {
    var subject: String
    var body: String
}

struct ATSResumeAudit: Equatable, Sendable {
    var score: Int
    var keywordCoverage: Int
    var missingKeywords: [String]
    var strengths: [String]
    var warnings: [String]
    var wordCount: Int

    static let empty = ATSResumeAudit(
        score: 0,
        keywordCoverage: 0,
        missingKeywords: [],
        strengths: [],
        warnings: ["Generate or paste a resume draft to run the ATS check."],
        wordCount: 0
    )
}

struct JobApplicationPlan: Equatable, Sendable {
    var readinessScore: Int
    var marketFit: String
    var authorizationFit: String
    var recommendedTemplate: ResumeTemplate
    var resumeFocus: String
    var missingKeywords: [String]
    var nextActions: [String]
    var interviewPrompts: [String]
}

struct ResumeVersion: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var template: ResumeTemplate
    var region: ResumeRegion
    var targetTitle: String
    var company: String
    var sourceJobID: UUID?
    var resumeText: String
    var atsScore: Int
    var createdAt: Date
    var updatedAt: Date
}

struct ResumeExportFile: Identifiable, Equatable, Sendable {
    let id = UUID()
    var format: ResumeExportFormat
    var url: URL
}

struct AnalyticsCounters: Equatable, Sendable {
    var generated = 0
    var opened = 0
}

enum AnalyticsEventName: String, Codable, Sendable {
    case profileSaved
    case demoProfileUsed
    case jobViewed
    case jobSaved
    case applicationGenerated
    case applicationCopied
    case draftSaved
    case emailOpened
    case applyLinkOpened
    case statusChanged
    case feedbackOpened
    case recommendationFeedback
    case shareOpened
    case resumeCopied
    case resumeGenerated
    case resumeExported
    case resumeVersionSaved
}

struct AnalyticsEvent: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let name: AnalyticsEventName
    let metadata: [String: String]
    let createdAt: Date
}
