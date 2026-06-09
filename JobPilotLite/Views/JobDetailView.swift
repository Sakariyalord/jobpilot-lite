import SwiftUI

struct JobDetailView: View {
    @EnvironmentObject private var store: AppStore
    var match: JobMatch
    @State private var showApplicationFlow = false
    @State private var showFullDetail = false
    @State private var targetedResumeMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(store.localizedJobTitle(match.job.title))
                        .font(.system(size: 28, weight: .bold))
                    Text(store.localizedCompany(match.job.company))
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    HStack {
                        Badge(text: store.t(match.label), color: .blue)
                        Badge(text: "\(match.score)%", color: .green)
                        if match.job.visaFriendly {
                            Badge(text: store.t("Visa friendly"), color: .purple)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    InfoLine(icon: "mappin.and.ellipse", title: store.t("Location"), value: "\(store.localizedJobCity(match.job.city)) / \(store.localizedRemoteType(match.job.remoteType))")
                    InfoLine(icon: "dollarsign.circle", title: store.t("Compensation"), value: store.localizedSalary(match.job.salary))
                    InfoLine(icon: match.job.contactEmail == nil ? "link" : "envelope", title: store.t("Apply method"), value: match.job.contactEmail ?? store.t("Apply link only"))
                    InfoLine(icon: "link", title: store.t("Source"), value: match.job.sourceURL)
                }

                ApplicationStrategyCard(match: match, savedMessage: $targetedResumeMessage)

                SectionBlock(title: store.t("Improve recommendations")) {
                    FeedbackGrid(job: match.job)
                }

                if showFullDetail {
                    SectionBlock(title: store.t("Why your resume matches")) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(match.reasons, id: \.self) { reason in
                                Label(store.localizedMatchReason(reason), systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    SectionBlock(title: store.t("Role summary")) {
                        Text(store.localizedRoleSummary(for: match.job))
                            .foregroundStyle(.secondary)
                    }

                    let localizedRequirements = store.localizedRequirements(for: match.job)
                    if !localizedRequirements.isEmpty {
                        SectionBlock(title: store.t("Requirements")) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(localizedRequirements.prefix(6).enumerated()), id: \.offset) { _, requirement in
                                    Label(requirement, systemImage: "target")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    SectionBlock(title: store.t("Skills")) {
                        FlowTags(tags: store.displayTags(for: match.job).map(store.localizedJobTag))
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 104)
        }
        .safeAreaInset(edge: .bottom) {
            DetailActionBar(job: match.job, showApplicationFlow: $showApplicationFlow)
        }
        .inlineNavigationTitle()
        .sheet(isPresented: $showApplicationFlow) {
            ApplicationFlowView(job: match.job)
        }
        .onAppear {
            store.log(.jobViewed, metadata: ["job_id": match.job.id.uuidString])
        }
        .task(id: match.id) {
            await Task.yield()
            await MainActor.run {
                showFullDetail = true
            }
        }
    }
}

struct ApplicationStrategyCard: View {
    @EnvironmentObject private var store: AppStore
    var match: JobMatch
    @Binding var savedMessage: String

    var body: some View {
        let plan = store.applicationPlan(for: match)

        SectionBlock(title: store.t("Application Strategy")) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(AppColor.tertiaryGroupedBackground, lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: CGFloat(plan.readinessScore) / 100)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(plan.readinessScore)%")
                            .font(.caption.weight(.bold))
                    }
                    .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.t("Readiness"))
                            .font(.subheadline.weight(.semibold))
                        Text(readinessLabel(for: plan.readinessScore))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                }

                VStack(alignment: .leading, spacing: 9) {
                    StrategyLine(icon: "globe.americas.fill", title: store.t("Target market"), value: plan.marketFit)
                    StrategyLine(icon: "person.badge.key.fill", title: store.t("Market & authorization"), value: plan.authorizationFit)
                    StrategyLine(icon: "doc.text.fill", title: store.t("Auto resume template"), value: store.t(plan.recommendedTemplate.title))
                    StrategyLine(icon: "doc.text.magnifyingglass", title: store.t("Resume focus"), value: plan.resumeFocus)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t("Missing keywords"))
                        .font(.subheadline.weight(.semibold))
                    if plan.missingKeywords.isEmpty {
                        Label(store.t("No missing keywords"), systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        FlowTags(tags: plan.missingKeywords.map(store.localizedJobTag))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t("Next actions"))
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(plan.nextActions.enumerated()), id: \.offset) { index, action in
                        StrategyBulletRow(index: index + 1, text: action)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t("Interview prep"))
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(plan.interviewPrompts.prefix(3).enumerated()), id: \.offset) { _, prompt in
                        StrategyBulletRow(icon: "sparkle.magnifyingglass", text: prompt)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        let score = store.saveTargetedResume(for: match)
                        savedMessage = "\(store.t("Targeted resume saved")) · \(store.t("ATS")) \(score)"
                    } label: {
                        Label(store.t("Save Targeted Resume"), systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        copyPlan(plan)
                    } label: {
                        Label(store.t("Copy Plan"), systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if !savedMessage.isEmpty {
                    Label(savedMessage, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private func readinessLabel(for score: Int) -> String {
        switch score {
        case 85...100:
            return store.t("Ready to apply after a final review")
        case 70..<85:
            return store.t("Good fit, improve the resume before applying")
        case 50..<70:
            return store.t("Useful lead, but fix gaps first")
        default:
            return store.t("Low readiness, save only if strategically important")
        }
    }

    private func copyPlan(_ plan: JobApplicationPlan) {
        let text = """
        \(store.t("Application Strategy")) - \(store.localizedJobTitle(match.job.title)) / \(store.localizedCompany(match.job.company))
        \(store.t("Readiness")): \(plan.readinessScore)%
        \(store.t("Target market")): \(plan.marketFit)
        \(store.t("Market & authorization")): \(plan.authorizationFit)
        \(store.t("Resume focus")): \(plan.resumeFocus)
        \(store.t("Missing keywords")): \(plan.missingKeywords.map(store.localizedJobTag).joined(separator: ", "))
        \(store.t("Next actions")):
        \(plan.nextActions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        \(store.t("Interview prep")):
        \(plan.interviewPrompts.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        """

        PlatformActions.copy(text)
        savedMessage = store.t("Copied application plan")
    }
}

struct StrategyLine: View {
    var icon: String
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct StrategyBulletRow: View {
    var index: Int?
    var icon: String?
    var text: String

    init(index: Int, text: String) {
        self.index = index
        self.icon = nil
        self.text = text
    }

    init(icon: String, text: String) {
        self.index = nil
        self.icon = icon
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if let index {
                Text("\(index)")
                    .font(.caption.weight(.bold))
                    .frame(width: 22, height: 22)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(Circle())
            } else if let icon {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.purple)
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FeedbackGrid: View {
    @EnvironmentObject private var store: AppStore
    var job: Job

    private var selectedReason: JobFeedbackReason? {
        store.feedback(for: job)?.reason
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
            ForEach(JobFeedbackReason.allCases) { reason in
                Button {
                    store.recordFeedback(for: job, reason: reason)
                } label: {
                    Label(store.t(reason.rawValue), systemImage: reason.systemImage)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedReason == reason ? .white : .primary)
                .background(selectedReason == reason ? Color.blue : AppColor.tertiaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct DetailActionBar: View {
    @EnvironmentObject private var store: AppStore
    var job: Job
    @Binding var showApplicationFlow: Bool

    var body: some View {
        VStack(spacing: 10) {
            Button {
                store.save(job: job, status: .saved)
                showApplicationFlow = true
            } label: {
                Label(store.t("Generate Resume & Apply"), systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                store.save(job: job, status: .saved)
            } label: {
                Label(store.t("Save Job"), systemImage: "bookmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(AppColor.groupedBackground)
    }

}

struct ApplicationFlowView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var job: Job

    @State private var subject = ""
    @State private var messageBody = ""
    @State private var resumeText = ""
    @State private var audit = ATSResumeAudit.empty
    @State private var statusMessage = ""
    @State private var exportFiles: [ResumeExportFile] = []
    @State private var didPrepare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ApplicationSourceCard(job: job)

                    SectionBlock(title: store.t("Application Kit")) {
                        VStack(alignment: .leading, spacing: 9) {
                            StrategyLine(icon: "doc.text.fill", title: store.t("ATS-friendly resume"), value: store.t(store.recommendedResumeTemplate(for: job).title))
                            StrategyLine(icon: "link.badge.plus", title: store.t("Apply method"), value: job.contactEmail ?? store.t("Apply link only"))
                            Text(store.t("Edit the resume before applying"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ATSScoreCard(audit: audit)

                    SectionBlock(title: store.t("Generated resume")) {
                        VStack(alignment: .leading, spacing: 12) {
                            TextEditor(text: $resumeText)
                                .font(.system(.footnote, design: .monospaced))
                                .padding(8)
                                .frame(minHeight: 360)
                                .background(.background)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onChange(of: resumeText) { _, _ in
                                    refreshAudit()
                                }

                            HStack(spacing: 10) {
                                Button {
                                    optimizeResume()
                                } label: {
                                    Label(store.t("Optimize ATS keywords"), systemImage: "wand.and.stars")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    copyResume()
                                } label: {
                                    Label(store.t("Copy Resume"), systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    SectionBlock(title: store.t("Recruiter note")) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField(store.t("Subject"), text: $subject)
                                .fieldStyle()

                            TextEditor(text: $messageBody)
                                .padding(8)
                                .frame(minHeight: 180)
                                .background(.background)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(store.t("The edited resume is attached below this note when you copy or email the application."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    SectionBlock(title: store.t("Apply from this app")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(store.t("The official apply link opens when the employer requires their ATS form. Your resume and note stay saved here."))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                openApplyURL()
                            } label: {
                                Label(store.t("Open Verified Apply Link"), systemImage: "safari")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)

                            if job.contactEmail != nil {
                                Button {
                                    emailRecruiter()
                                } label: {
                                    Label(store.t("Email Recruiter"), systemImage: "envelope.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    saveMaterials(markApplied: false)
                                } label: {
                                    Label(store.t("Save Resume"), systemImage: "tray.and.arrow.down")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    copyApplication()
                                } label: {
                                    Label(store.t("Copy Application"), systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }

                            Button {
                                buildUploadFiles()
                            } label: {
                                Label(store.t("Build Upload Files"), systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            if !exportFiles.isEmpty {
                                HStack(spacing: 10) {
                                    ForEach(exportFiles) { file in
                                        ShareLink(item: file.url) {
                                            Label(file.format.rawValue, systemImage: file.format.systemImage)
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }

                            if !statusMessage.isEmpty {
                                Label(statusMessage, systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppColor.groupedBackground)
            .navigationTitle(store.t("Application Kit"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: AppToolbarPlacement.trailing) {
                    Button(store.t("Done")) { dismiss() }
                }
            }
            .onAppear {
                prepareIfNeeded()
            }
        }
    }

    private var jobDescription: String {
        store.jobDescriptionText(for: job)
    }

    private var signature: String {
        [
            "Best,",
            store.profile.fullName,
            store.profile.email,
            store.profile.phone
        ]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }

    private var fullApplicationMessage: String {
        [
            messageBody.trimmingCharacters(in: .whitespacesAndNewlines),
            "---",
            resumeText.trimmingCharacters(in: .whitespacesAndNewlines),
            signature
        ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func prepareIfNeeded() {
        guard !didPrepare else { return }
        didPrepare = true

        resumeText = store.generateResumeText(
            template: store.recommendedResumeTemplate(for: job),
            region: store.profile.resumeRegion,
            targetJobTitle: job.title,
            company: job.company,
            jobDescription: jobDescription
        )
        refreshAudit()

        let message = store.generateMessage(for: job)
        subject = message.subject
        messageBody = applicationNote(from: message.body)
        store.saveDraft(for: job, subject: subject, body: fullApplicationMessage)
    }

    private func applicationNote(from generatedBody: String) -> String {
        let marker = "\n---\n"
        if let range = generatedBody.range(of: marker) {
            return String(generatedBody[..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return generatedBody.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func refreshAudit() {
        audit = store.analyzeResumeText(resumeText, targetJobTitle: job.title, jobDescription: jobDescription)
    }

    private func optimizeResume() {
        resumeText = store.rewriteResumeDraft(resumeText, targetJobTitle: job.title, jobDescription: jobDescription)
        refreshAudit()
        statusMessage = store.t("ATS keywords updated")
    }

    @discardableResult
    private func saveMaterials(markApplied: Bool) -> Int {
        let score = store.saveEditedTargetedResume(for: job, text: resumeText)
        store.saveDraft(for: job, subject: subject, body: fullApplicationMessage)
        if markApplied {
            store.save(job: job, status: .applied)
        } else if store.application(for: job) == nil {
            store.save(job: job, status: .saved)
        }
        statusMessage = "\(store.t("Generated materials saved")) · \(store.t("ATS")) \(score)"
        return score
    }

    private func copyResume() {
        saveMaterials(markApplied: false)
        PlatformActions.copy(resumeText)
        store.log(.resumeCopied, metadata: ["job_id": job.id.uuidString])
        statusMessage = store.t("Copied resume")
    }

    private func copyApplication() {
        saveMaterials(markApplied: false)
        PlatformActions.copy(fullApplicationMessage)
        store.log(.applicationCopied, metadata: ["job_id": job.id.uuidString])
        statusMessage = store.t("Copied application")
    }

    private func buildUploadFiles() {
        let score = saveMaterials(markApplied: false)
        let title = "\(job.title) - \(job.company)"
        exportFiles = PlatformActions.writeResumeExports(text: resumeText, title: title)
        store.log(.resumeExported, metadata: ["job_id": job.id.uuidString])
        statusMessage = "\(store.t("Files ready")) · \(store.t("ATS")) \(score)"
    }

    private func openApplyURL() {
        let score = saveMaterials(markApplied: true)
        guard let url = URL(string: job.sourceURL) else {
            statusMessage = "\(store.t("Generated materials saved")) · \(store.t("ATS")) \(score)"
            return
        }
        store.log(.applyLinkOpened, metadata: ["job_id": job.id.uuidString])
        PlatformActions.open(url)
    }

    private func emailRecruiter() {
        let score = saveMaterials(markApplied: true)
        guard let contactEmail = job.contactEmail,
              let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = fullApplicationMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "mailto:\(contactEmail)?subject=\(encodedSubject)&body=\(encodedBody)") else {
            PlatformActions.copy(fullApplicationMessage)
            store.log(.applicationCopied, metadata: ["job_id": job.id.uuidString])
            statusMessage = "\(store.t("Copied application")) · \(store.t("ATS")) \(score)"
            return
        }

        store.log(.emailOpened, metadata: ["job_id": job.id.uuidString])
        PlatformActions.open(url)
    }
}

struct ApplicationSourceCard: View {
    @EnvironmentObject private var store: AppStore
    var job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(store.t("Real apply link"), systemImage: "checkmark.shield")
                    .font(.headline)
                Spacer()
                Text(job.contactEmail == nil ? store.t("Apply link") : store.t("Contact"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.12))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }

            Text(store.t("Use this page to generate, edit, save, and submit job-specific materials."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(AppColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct MessageComposerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var job: Job
    @State private var subject = ""
    @State private var messageBody = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TextField(store.t("Subject"), text: $subject)
                    .fieldStyle()

                TextEditor(text: $messageBody)
                    .padding(8)
                    .frame(minHeight: 340)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 12) {
                    Button {
                        PlatformActions.copy(messageBody)
                        store.saveDraft(for: job, subject: subject, body: messageBody)
                        store.log(.applicationCopied, metadata: ["job_id": job.id.uuidString])
                    } label: {
                        Label(store.t("Copy"), systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        store.save(job: job, status: .applied)
                        openMail()
                    } label: {
                        Label(store.t("Email"), systemImage: "envelope.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
            .background(AppColor.groupedBackground)
            .navigationTitle(store.t("Application"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: AppToolbarPlacement.trailing) {
                    Button(store.t("Done")) { dismiss() }
                }
            }
            .onAppear {
                let message = store.generateMessage(for: job)
                subject = message.subject
                messageBody = message.body
                store.saveDraft(for: job, subject: subject, body: messageBody)
            }
            .onDisappear {
                store.saveDraft(for: job, subject: subject, body: messageBody)
            }
        }
    }

    private func openMail() {
        store.saveDraft(for: job, subject: subject, body: messageBody)
        _ = store.saveTargetedResume(for: job)
        guard let contactEmail = job.contactEmail,
              let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = messageBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "mailto:\(contactEmail)?subject=\(encodedSubject)&body=\(encodedBody)") else {
            PlatformActions.copy(messageBody)
            store.log(.applicationCopied, metadata: ["job_id": job.id.uuidString])
            return
        }
        store.log(.emailOpened, metadata: ["job_id": job.id.uuidString])
        PlatformActions.open(url)
    }
}

struct SectionBlock<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct InfoLine: View {
    var icon: String
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .lineLimit(2)
            }
        }
    }
}

struct Badge: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct FlowTags: View {
    var tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                Text(tag)
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(AppColor.tertiaryGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
