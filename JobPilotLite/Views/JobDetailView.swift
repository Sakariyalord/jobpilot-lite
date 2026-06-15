import SwiftUI

#if canImport(UIKit) && canImport(WebKit)
import WebKit
#endif

#if canImport(UIKit) && canImport(MessageUI)
import MessageUI
#endif

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
                    InfoLine(icon: match.job.canBypassEmployerATS ? "envelope.fill" : "link", title: store.t("Apply method"), value: store.t(match.job.applyChannel.rawValue))
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
    @State private var showApplyWorkspace = false
    @State private var directMailPayload: DirectMailPayload?

    var body: some View {
        let adapterPlan = ApplyAdapterPlan(job: job)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ApplicationSourceCard(job: job)

                    SectionBlock(title: store.t("Application Kit")) {
                        VStack(alignment: .leading, spacing: 9) {
                            StrategyLine(icon: "doc.text.fill", title: store.t("ATS-friendly resume"), value: store.t(store.recommendedResumeTemplate(for: job).title))
                            StrategyLine(icon: job.canBypassEmployerATS ? "envelope.fill" : "link.badge.plus", title: store.t("Apply method"), value: store.t(job.applyChannel.rawValue))
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
                            ApplyAdapterSummary(plan: adapterPlan)

                            Text(store.t(adapterPlan.explanationKey))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if job.canBypassEmployerATS {
                                Button {
                                    sendATSFreeApplication()
                                } label: {
                                    Label(store.t("Send ATS-Free Direct Application"), systemImage: "paperplane.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)

                                Button {
                                    openApplyWorkspace()
                                } label: {
                                    Label(store.t("Open employer ATS backup"), systemImage: "rectangle.and.pencil.and.ellipsis")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            } else {
                                Label(store.t("This job has no verified direct apply channel. JobPilot cannot fully bypass this employer ATS."), systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)

                                Button {
                                    openApplyWorkspace()
                                } label: {
                                    Label(store.t("Open ATS Helper"), systemImage: "rectangle.and.pencil.and.ellipsis")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
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

                    ApplyAutomationPreview(
                        plan: adapterPlan,
                        profileFields: applyProfileFields,
                        screeningAnswers: applyScreeningAnswers,
                        copyAllAction: copyApplyPacket
                    )
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
            .sheet(isPresented: $showApplyWorkspace) {
                ApplyWorkspaceView(
                    job: job,
                    plan: adapterPlan,
                    subject: subject,
                    resumeText: resumeText,
                    messageBody: messageBody,
                    profileFields: applyProfileFields,
                    screeningAnswers: applyScreeningAnswers
                )
            }
            .sheet(item: $directMailPayload) { payload in
                DirectMailComposeView(payload: payload) { result in
                    handleDirectMailResult(result)
                }
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

    private var applyProfileFields: [ApplyFieldValue] {
        ApplyFieldValue.profilePacket(profile: store.profile, job: job, workRightsLine: store.workRightsResumeLine())
    }

    private var applyScreeningAnswers: [ApplyFieldValue] {
        ApplyFieldValue.screeningPacket(profile: store.profile, job: job, workRightsLine: store.workRightsResumeLine())
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

    private func openApplyWorkspace() {
        let score = saveMaterials(markApplied: false)
        store.log(.applyLinkOpened, metadata: ["job_id": job.id.uuidString])
        statusMessage = "\(store.t("Application workspace ready")) · \(store.t("ATS")) \(score)"
        showApplyWorkspace = true
    }

    private func sendATSFreeApplication() {
        let score = saveMaterials(markApplied: false)
        let title = "\(job.title) - \(job.company)"
        let files = PlatformActions.writeResumeExports(text: resumeText, title: title)
        exportFiles = files

        guard let email = job.directApplyAddress else {
            PlatformActions.copy(fullApplicationMessage)
            store.log(.applicationCopied, metadata: ["job_id": job.id.uuidString])
            statusMessage = "\(store.t("No direct apply channel found")) · \(store.t("ATS")) \(score)"
            return
        }

        let payload = DirectMailPayload(
            to: email,
            subject: subject,
            body: fullApplicationMessage,
            attachments: files.map(\.url)
        )

        if DirectMailComposeView.canSendMail {
            directMailPayload = payload
        } else {
            openMailto(payload: payload)
            statusMessage = "\(store.t("Mail draft opened")) · \(store.t("ATS")) \(score)"
        }
    }

    private func openMailto(payload: DirectMailPayload) {
        guard let encodedSubject = payload.subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = payload.body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "mailto:\(payload.to)?subject=\(encodedSubject)&body=\(encodedBody)") else {
            PlatformActions.copy(payload.body)
            store.log(.applicationCopied, metadata: ["job_id": job.id.uuidString])
            return
        }

        store.log(.emailOpened, metadata: ["job_id": job.id.uuidString])
        PlatformActions.open(url)
    }

    private func handleDirectMailResult(_ result: DirectMailResult) {
        switch result {
        case .sent:
            store.save(job: job, status: .applied)
            store.log(.emailOpened, metadata: ["job_id": job.id.uuidString])
            statusMessage = store.t("ATS-free application sent")
        case .saved:
            store.saveDraft(for: job, subject: subject, body: fullApplicationMessage)
            statusMessage = store.t("Mail draft saved")
        case .cancelled:
            statusMessage = store.t("Direct application cancelled")
        case .failed:
            PlatformActions.copy(fullApplicationMessage)
            store.log(.applicationCopied, metadata: ["job_id": job.id.uuidString])
            statusMessage = store.t("Mail unavailable; application copied")
        }
    }

    private func copyApplyPacket() {
        saveMaterials(markApplied: false)
        let packet = ApplyAdapterPlan(job: job).copyPacket(
            job: job,
            subject: subject,
            resumeText: resumeText,
            messageBody: messageBody,
            profileFields: applyProfileFields,
            screeningAnswers: applyScreeningAnswers
        )
        PlatformActions.copy(packet)
        store.log(.applicationCopied, metadata: ["job_id": job.id.uuidString])
        statusMessage = store.t("Copied application autofill packet")
    }

}

private enum ApplyAdapterMode: Sendable {
    case direct
    case standard
    case embedded
    case accountHeavy
    case universal
}

private struct DirectMailPayload: Identifiable, Equatable, Sendable {
    let id = UUID()
    var to: String
    var subject: String
    var body: String
    var attachments: [URL]
}

private enum DirectMailResult: Sendable {
    case sent
    case saved
    case cancelled
    case failed
}

#if canImport(UIKit) && canImport(MessageUI)
private struct DirectMailComposeView: UIViewControllerRepresentable {
    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    var payload: DirectMailPayload
    var completion: (DirectMailResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([payload.to])
        controller.setSubject(payload.subject)
        controller.setMessageBody(payload.body, isHTML: false)

        for url in payload.attachments {
            guard let data = try? Data(contentsOf: url) else { continue }
            controller.addAttachmentData(data, mimeType: mimeType(for: url), fileName: url.lastPathComponent)
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "rtf": return "application/rtf"
        default: return "text/plain"
        }
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var completion: (DirectMailResult) -> Void

        init(completion: @escaping (DirectMailResult) -> Void) {
            self.completion = completion
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)

            if error != nil {
                completion(.failed)
                return
            }

            switch result {
            case .sent:
                completion(.sent)
            case .saved:
                completion(.saved)
            case .cancelled:
                completion(.cancelled)
            case .failed:
                completion(.failed)
            @unknown default:
                completion(.failed)
            }
        }
    }
}
#else
private struct DirectMailComposeView: View {
    static var canSendMail: Bool { false }
    var payload: DirectMailPayload
    var completion: (DirectMailResult) -> Void

    var body: some View {
        ContentUnavailableView(
            "Mail unavailable",
            systemImage: "envelope.badge",
            description: Text(payload.to)
        )
        .onAppear {
            completion(.failed)
        }
    }
}
#endif

private struct ApplyAdapterPlan: Equatable, Sendable {
    var platformName: String
    var mode: ApplyAdapterMode
    var summaryKey: String
    var frictionKey: String
    var explanationKey: String
    var capabilityKeys: [String]
    var warningKeys: [String]

    init(job: Job) {
        let rawURL = job.sourceURL.lowercased()
        let host = URL(string: job.sourceURL)?.host?.lowercased() ?? ""

        if job.canBypassEmployerATS {
            platformName = "ATS-free"
            mode = .direct
            summaryKey = "Direct apply channel ready"
            frictionKey = "No ATS"
        } else if host.contains("lever.co") {
            platformName = "Lever"
            mode = .standard
            summaryKey = "Standard ATS adapter ready"
            frictionKey = "Low friction"
        } else if host.contains("greenhouse.io") || rawURL.contains("gh_jid=") {
            platformName = "Greenhouse"
            mode = .standard
            summaryKey = "Standard ATS adapter ready"
            frictionKey = "Low friction"
        } else if host.contains("ashbyhq.com") {
            platformName = "Ashby"
            mode = .standard
            summaryKey = "Standard ATS adapter ready"
            frictionKey = "Low friction"
        } else if host.contains("smartrecruiters.com") {
            platformName = "SmartRecruiters"
            mode = .embedded
            summaryKey = "Embedded ATS adapter ready"
            frictionKey = "Medium friction"
        } else if host.contains("recruitee.com") || host.contains("workable.com") || host.contains("breezy.hr") || host.contains("jazz.co") || host.contains("bamboohr.com") {
            platformName = "ATS"
            mode = .embedded
            summaryKey = "Embedded ATS adapter ready"
            frictionKey = "Medium friction"
        } else if host.contains("myworkdayjobs.com") || host.contains("workdayjobs.com") {
            platformName = "Workday"
            mode = .accountHeavy
            summaryKey = "Account-heavy adapter ready"
            frictionKey = "High friction"
        } else if host.contains("icims.com") || host.contains("successfactors.com") || host.contains("taleo.net") || host.contains("oraclecloud.com") {
            platformName = "Enterprise ATS"
            mode = .accountHeavy
            summaryKey = "Account-heavy adapter ready"
            frictionKey = "High friction"
        } else {
            platformName = host.isEmpty ? "Apply site" : host
            mode = .universal
            summaryKey = "Universal adapter ready"
            frictionKey = "Unknown friction"
        }

        switch mode {
        case .direct:
            explanationKey = "This job has a verified direct apply channel. JobPilot can prepare the resume and open an in-app email composer without sending the user through the employer ATS."
            capabilityKeys = [
                "No employer ATS form",
                "In-app email composer",
                "Resume attached",
                "Profile autofill packet",
                "Final user confirmation"
            ]
            warningKeys = ["Only use direct apply when the employer provided this channel"]
        case .standard:
            explanationKey = "This employer still requires its ATS. JobPilot cannot fully bypass it, but it keeps the page inside the app and prepares every field before final confirmation."
            capabilityKeys = [
                "In-app application page",
                "Resume upload files",
                "Profile autofill packet",
                "Screening answer bank",
                "Final user confirmation"
            ]
            warningKeys = ["Review custom questions before submitting"]
        case .embedded:
            explanationKey = "This employer still requires its ATS. JobPilot cannot fully bypass it, but it keeps the page inside the app and prepares every field before final confirmation."
            capabilityKeys = [
                "In-app application page",
                "Resume upload files",
                "Profile autofill packet",
                "Screening answer bank",
                "Copy-safe formatted answers"
            ]
            warningKeys = ["Some fields may still require manual confirmation"]
        case .accountHeavy:
            explanationKey = "This employer still requires account-based ATS steps. JobPilot cannot bypass login, account creation, or employer verification screens."
            capabilityKeys = [
                "In-app application page",
                "Account setup helper",
                "Profile autofill packet",
                "Screening answer bank",
                "Copy-safe formatted answers"
            ]
            warningKeys = [
                "This ATS may require login or account creation",
                "Review every parsed resume field before submitting"
            ]
        case .universal:
            explanationKey = "No verified direct apply channel is available. JobPilot can only assist with the employer page and prepared answers."
            capabilityKeys = [
                "In-app application page",
                "Resume upload files",
                "Profile autofill packet",
                "Screening answer bank",
                "Copy-safe formatted answers"
            ]
            warningKeys = ["Universal mode cannot guarantee every field is detectable"]
        }
    }

    func copyPacket(
        job: Job,
        subject: String,
        resumeText: String,
        messageBody: String,
        profileFields: [ApplyFieldValue],
        screeningAnswers: [ApplyFieldValue]
    ) -> String {
        """
        JobPilot Application Packet
        Platform: \(platformName)
        Role: \(job.title)
        Company: \(job.company)
        Apply URL: \(job.sourceURL)

        Profile fields:
        \(profileFields.map { "\($0.label): \($0.value)" }.joined(separator: "\n"))

        Screening answers:
        \(screeningAnswers.map { "\($0.label): \($0.value)" }.joined(separator: "\n\n"))

        Subject:
        \(subject)

        Recruiter note / additional information:
        \(messageBody)

        Resume:
        \(resumeText)
        """
    }
}

private struct ApplyFieldValue: Identifiable, Equatable, Sendable {
    var id: String { label }
    var label: String
    var value: String
    var systemImage: String

    static func profilePacket(profile: CandidateProfile, job: Job, workRightsLine: String) -> [ApplyFieldValue] {
        [
            ApplyFieldValue(label: "Full name", value: profile.fullName, systemImage: "person.text.rectangle"),
            ApplyFieldValue(label: "Email address", value: profile.email, systemImage: "envelope"),
            ApplyFieldValue(label: "Phone", value: profile.phone, systemImage: "phone"),
            ApplyFieldValue(label: "Current city", value: profile.city, systemImage: "mappin.and.ellipse"),
            ApplyFieldValue(label: "Preferred location", value: profile.preferredLocation.isEmpty ? job.city : profile.preferredLocation, systemImage: "location"),
            ApplyFieldValue(label: "Target role", value: profile.targetTitle, systemImage: "briefcase"),
            ApplyFieldValue(label: "Work mode", value: profile.workModePreference.rawValue, systemImage: "desktopcomputer"),
            ApplyFieldValue(label: "Opportunity type", value: profile.opportunityType.rawValue, systemImage: "clock.badge.checkmark"),
            ApplyFieldValue(label: "Experience level", value: profile.experienceLevel.rawValue, systemImage: "chart.line.uptrend.xyaxis"),
            ApplyFieldValue(label: "Work authorization", value: workRightsLine, systemImage: "person.badge.key"),
            ApplyFieldValue(label: "Visa preference", value: profile.visaPreference, systemImage: "doc.badge.gearshape"),
            ApplyFieldValue(label: "Languages", value: profile.languages, systemImage: "globe"),
            ApplyFieldValue(label: "Skills", value: profile.skills.joined(separator: ", "), systemImage: "sparkles"),
            ApplyFieldValue(label: "Education", value: profile.education, systemImage: "graduationcap"),
            ApplyFieldValue(label: "Certifications", value: profile.certifications, systemImage: "checkmark.seal"),
            ApplyFieldValue(label: "Portfolio URL", value: profile.portfolioURL, systemImage: "link")
        ]
        .filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func screeningPacket(profile: CandidateProfile, job: Job, workRightsLine: String) -> [ApplyFieldValue] {
        [
            ApplyFieldValue(label: "Authorized to work answer", value: authorizedToWorkAnswer(profile: profile, workRightsLine: workRightsLine), systemImage: "person.badge.key.fill"),
            ApplyFieldValue(label: "Sponsorship answer", value: sponsorshipAnswer(profile: profile), systemImage: "doc.badge.gearshape.fill"),
            ApplyFieldValue(label: "Location answer", value: locationAnswer(profile: profile, job: job), systemImage: "mappin.circle.fill"),
            ApplyFieldValue(label: "Start date answer", value: "Available to discuss. I can provide an exact start date during the process.", systemImage: "calendar.badge.clock"),
            ApplyFieldValue(label: "Salary answer", value: salaryAnswer(job: job), systemImage: "dollarsign.circle.fill"),
            ApplyFieldValue(label: "Why this role answer", value: whyThisRoleAnswer(profile: profile, job: job), systemImage: "sparkle.magnifyingglass")
        ]
    }

    private static func authorizedToWorkAnswer(profile: CandidateProfile, workRightsLine: String) -> String {
        switch profile.workAuthorizationStatus {
        case .unknown:
            return "My work authorization should be confirmed for this role. \(workRightsLine)"
        case .needsSponsorship:
            return "I require employer sponsorship or immigration support for this target market."
        default:
            return workRightsLine
        }
    }

    private static func sponsorshipAnswer(profile: CandidateProfile) -> String {
        switch profile.workAuthorizationStatus {
        case .needsSponsorship:
            return "Yes, I require employer sponsorship."
        case .studentOrGraduate:
            return "I may require sponsorship depending on timing and visa route. Details are available on request."
        case .unknown:
            return "To be confirmed based on the role, location, and employer policy."
        default:
            return "No employer sponsorship is required based on my current work authorization status."
        }
    }

    private static func locationAnswer(profile: CandidateProfile, job: Job) -> String {
        let target = profile.preferredLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetText = target.isEmpty ? job.city : target
        return "I am targeting \(targetText) and am open to \(profile.workModePreference.rawValue.lowercased()) roles when aligned with the employer's requirements."
    }

    private static func salaryAnswer(job: Job) -> String {
        if job.salary.localizedCaseInsensitiveCompare("Not listed") == .orderedSame {
            return "Open to discussing compensation based on the role scope, location, and total package."
        }
        return "Open to the posted range of \(job.salary), depending on scope, location, and total package."
    }

    private static func whyThisRoleAnswer(profile: CandidateProfile, job: Job) -> String {
        let skills = profile.skills.prefix(4).joined(separator: ", ")
        let experience = profile.recentExperience.trimmingCharacters(in: .whitespacesAndNewlines)
        let evidence = experience.isEmpty ? "my background in \(skills)" : experience
        return "I am interested in \(job.title) at \(job.company) because the role aligns with \(evidence). I can bring \(skills) and role-specific execution to support the team's goals."
    }
}

private struct ApplyAdapterSummary: View {
    @EnvironmentObject private var store: AppStore
    var plan: ApplyAdapterPlan

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12))
                .foregroundStyle(tint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.platformName)
                    .font(.subheadline.weight(.semibold))
                Text(store.t(plan.summaryKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(store.t(plan.frictionKey))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(tint.opacity(0.12))
                .foregroundStyle(tint)
                .clipShape(Capsule())
        }
    }

    private var icon: String {
        switch plan.mode {
        case .direct: return "paperplane.fill"
        case .standard: return "checkmark.seal.fill"
        case .embedded: return "rectangle.connected.to.line.below"
        case .accountHeavy: return "person.crop.circle.badge.exclamationmark"
        case .universal: return "wand.and.stars"
        }
    }

    private var tint: Color {
        switch plan.mode {
        case .direct: return .green
        case .standard: return .green
        case .embedded: return .blue
        case .accountHeavy: return .orange
        case .universal: return .purple
        }
    }
}

private struct ApplyAutomationPreview: View {
    @EnvironmentObject private var store: AppStore
    var plan: ApplyAdapterPlan
    var profileFields: [ApplyFieldValue]
    var screeningAnswers: [ApplyFieldValue]
    var copyAllAction: () -> Void

    var body: some View {
        SectionBlock(title: store.t("Autofill coverage")) {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 8)], spacing: 8) {
                    ForEach(plan.capabilityKeys, id: \.self) { capability in
                        Label(store.t(capability), systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.10))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                ForEach(plan.warningKeys, id: \.self) { warning in
                    Label(store.t(warning), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Button {
                    copyAllAction()
                } label: {
                    Label(store.t("Copy autofill packet"), systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t("Prepared profile fields"))
                        .font(.subheadline.weight(.semibold))
                    ForEach(profileFields.prefix(5)) { field in
                        ApplyFieldRow(field: field)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t("Prepared screening answers"))
                        .font(.subheadline.weight(.semibold))
                    ForEach(screeningAnswers.prefix(3)) { field in
                        ApplyFieldRow(field: field)
                    }
                }
            }
        }
    }
}

private struct ApplyWorkspaceView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var job: Job
    var plan: ApplyAdapterPlan
    var subject: String
    var resumeText: String
    var messageBody: String
    var profileFields: [ApplyFieldValue]
    var screeningAnswers: [ApplyFieldValue]
    @State private var statusMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let url = URL(string: job.sourceURL) {
                    ApplyWebView(url: url)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 320)
                        .layoutPriority(1)
                } else {
                    ContentUnavailableView(
                        store.t("Apply link unavailable"),
                        systemImage: "link.badge.plus",
                        description: Text(store.t("Use the autofill packet below to continue."))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ApplyAdapterSummary(plan: plan)

                        SectionBlock(title: store.t("Autofill packet")) {
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    copyAll()
                                } label: {
                                    Label(store.t("Copy autofill packet"), systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)

                                ForEach(profileFields) { field in
                                    ApplyFieldRow(field: field)
                                }
                            }
                        }

                        SectionBlock(title: store.t("Screening answers")) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(screeningAnswers) { field in
                                    ApplyFieldRow(field: field)
                                }
                            }
                        }

                        SectionBlock(title: store.t("Generated materials")) {
                            VStack(spacing: 10) {
                                Button {
                                    PlatformActions.copy(resumeText)
                                    statusMessage = store.t("Copied resume")
                                } label: {
                                    Label(store.t("Copy Resume"), systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    PlatformActions.copy(messageBody)
                                    statusMessage = store.t("Copied application")
                                } label: {
                                    Label(store.t("Copy Application"), systemImage: "text.quote")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                if !statusMessage.isEmpty {
                                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 380)
                .background(AppColor.groupedBackground)
            }
            .navigationTitle(store.t("Apply Workspace"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: AppToolbarPlacement.trailing) {
                    Button(store.t("Done")) { dismiss() }
                }
            }
        }
    }

    private func copyAll() {
        let packet = plan.copyPacket(
            job: job,
            subject: subject,
            resumeText: resumeText,
            messageBody: messageBody,
            profileFields: profileFields,
            screeningAnswers: screeningAnswers
        )
        PlatformActions.copy(packet)
        statusMessage = store.t("Copied application autofill packet")
    }
}

private struct ApplyFieldRow: View {
    @EnvironmentObject private var store: AppStore
    var field: ApplyFieldValue
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: field.systemImage)
                .frame(width: 22)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 3) {
                Text(store.t(field.label))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(field.value)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                PlatformActions.copy(field.value)
                copied = true
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(store.t("Copy"))
        }
        .padding(10)
        .background(AppColor.tertiaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#if canImport(UIKit) && canImport(WebKit)
private struct ApplyWebView: UIViewRepresentable {
    var url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}
#else
private struct ApplyWebView: View {
    var url: URL

    var body: some View {
        ContentUnavailableView(
            "In-app web view unavailable",
            systemImage: "safari",
            description: Text(url.absoluteString)
        )
    }
}
#endif

struct ApplicationSourceCard: View {
    @EnvironmentObject private var store: AppStore
    var job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(store.t(job.canBypassEmployerATS ? "ATS-free direct channel" : "Employer ATS required"), systemImage: job.canBypassEmployerATS ? "paperplane.fill" : "checkmark.shield")
                    .font(.headline)
                Spacer()
                Text(store.t(job.canBypassEmployerATS ? "Direct" : "ATS"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background((job.canBypassEmployerATS ? Color.green : Color.orange).opacity(0.12))
                    .foregroundStyle(job.canBypassEmployerATS ? .green : .orange)
                    .clipShape(Capsule())
            }

            Text(store.t(job.canBypassEmployerATS ? "Use this page to generate, edit, and send a direct application without the employer ATS." : "Use this page to generate, edit, and prepare materials. This employer still requires its ATS for the final application."))
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
