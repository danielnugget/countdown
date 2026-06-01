import CountdownShared
import SwiftUI

enum CountdownEditorMode: Identifiable {
    case createDate
    case edit(CountdownSnapshot)

    var id: String {
        switch self {
        case .createDate: "createDate"
        case .edit(let snapshot): "edit-\(snapshot.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .createDate: "New Countdown"
        case .edit: "Edit Countdown"
        }
    }
}

struct CountdownEditorRequest {
    var mode: CountdownEditorMode
    var title: String
    var targetDate: Date
    var colorName: String
    var symbolName: String
    var tags: [String]
    var collectionName: String?
}

private struct CountdownEditorSymbol: Identifiable {
    let id: String
    let title: String
    let keywords: [String]

    func matches(_ query: String) -> Bool {
        let tokens = query.searchTokens
        guard !tokens.isEmpty else {
            return true
        }

        let searchableText = ([title, id] + keywords)
            .joined(separator: " ")
            .normalizedForSymbolSearch

        return tokens.allSatisfy { searchableText.contains($0) }
    }
}

private extension String {
    var normalizedForSymbolSearch: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }

    var searchTokens: [String] {
        normalizedForSymbolSearch
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }
}

struct CountdownEditorView: View {
    let mode: CountdownEditorMode
    let onSave: (CountdownEditorRequest) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var targetDate: Date
    @State private var colorName: String
    @State private var symbolName: String
    @State private var tags: [String]
    @State private var collectionName: String
    @State private var tagDraft = ""
    @State private var symbolSearchText = ""

    private let colors = ["blue", "indigo", "purple", "pink", "red", "orange", "yellow", "green", "mint", "teal", "cyan", "brown", "gray"]
    private let symbols = [
        CountdownEditorSymbol(id: "calendar", title: "Calendar", keywords: ["date", "event", "schedule"]),
        CountdownEditorSymbol(id: "calendar.badge.clock", title: "Deadline", keywords: ["date", "time", "schedule"]),
        CountdownEditorSymbol(id: "clock", title: "Clock", keywords: ["time"]),
        CountdownEditorSymbol(id: "timer", title: "Timer", keywords: ["time"]),
        CountdownEditorSymbol(id: "hourglass", title: "Hourglass", keywords: ["time", "waiting"]),
        CountdownEditorSymbol(id: "flag.checkered", title: "Goal", keywords: ["finish", "race"]),
        CountdownEditorSymbol(id: "flag", title: "Milestone", keywords: ["goal", "marker"]),
        CountdownEditorSymbol(id: "bell", title: "Reminder", keywords: ["alert", "notification"]),
        CountdownEditorSymbol(id: "alarm", title: "Alarm", keywords: ["alert", "wake"]),
        CountdownEditorSymbol(id: "birthday.cake", title: "Birthday", keywords: ["party", "celebration"]),
        CountdownEditorSymbol(id: "party.popper", title: "Celebration", keywords: ["party", "special"]),
        CountdownEditorSymbol(id: "gift", title: "Gift", keywords: ["present", "holiday"]),
        CountdownEditorSymbol(id: "sparkles", title: "Special", keywords: ["celebration", "magic"]),
        CountdownEditorSymbol(id: "star", title: "Star", keywords: ["favorite", "important"]),
        CountdownEditorSymbol(id: "heart", title: "Heart", keywords: ["love", "health"]),
        CountdownEditorSymbol(id: "briefcase", title: "Work", keywords: ["job", "business"]),
        CountdownEditorSymbol(id: "building.2", title: "Office", keywords: ["work", "business"]),
        CountdownEditorSymbol(id: "graduationcap", title: "School", keywords: ["education", "study"]),
        CountdownEditorSymbol(id: "book", title: "Reading", keywords: ["study", "library"]),
        CountdownEditorSymbol(id: "pencil.and.outline", title: "Writing", keywords: ["creative", "notes"]),
        CountdownEditorSymbol(id: "checklist", title: "Checklist", keywords: ["task", "todo"]),
        CountdownEditorSymbol(id: "airplane", title: "Travel", keywords: ["flight", "trip"]),
        CountdownEditorSymbol(id: "suitcase", title: "Trip", keywords: ["travel", "vacation"]),
        CountdownEditorSymbol(id: "car", title: "Car", keywords: ["drive", "road"]),
        CountdownEditorSymbol(id: "bicycle", title: "Bike", keywords: ["cycling", "ride"]),
        CountdownEditorSymbol(id: "tram", title: "Transit", keywords: ["train", "commute"]),
        CountdownEditorSymbol(id: "mappin.and.ellipse", title: "Location", keywords: ["place", "map"]),
        CountdownEditorSymbol(id: "globe", title: "World", keywords: ["travel", "global"]),
        CountdownEditorSymbol(id: "house", title: "Home", keywords: ["family", "move"]),
        CountdownEditorSymbol(id: "sportscourt", title: "Sports", keywords: ["game", "match"]),
        CountdownEditorSymbol(id: "soccerball", title: "Match", keywords: ["sports", "game"]),
        CountdownEditorSymbol(id: "dumbbell", title: "Workout", keywords: ["fitness", "gym"]),
        CountdownEditorSymbol(id: "figure.run", title: "Race", keywords: ["fitness", "running"]),
        CountdownEditorSymbol(id: "gamecontroller", title: "Gaming", keywords: ["play", "release"]),
        CountdownEditorSymbol(id: "music.note", title: "Music", keywords: ["concert", "song"]),
        CountdownEditorSymbol(id: "theatermasks", title: "Show", keywords: ["theater", "performance"]),
        CountdownEditorSymbol(id: "film", title: "Film", keywords: ["movie", "cinema"]),
        CountdownEditorSymbol(id: "camera", title: "Camera", keywords: ["photo", "shoot"]),
        CountdownEditorSymbol(id: "paintpalette", title: "Art", keywords: ["creative", "design"]),
        CountdownEditorSymbol(id: "bolt", title: "Energy", keywords: ["power", "launch"]),
        CountdownEditorSymbol(id: "flame", title: "Launch", keywords: ["release", "energy"]),
        CountdownEditorSymbol(id: "leaf", title: "Nature", keywords: ["garden", "outdoor"]),
        CountdownEditorSymbol(id: "sun.max", title: "Sun", keywords: ["summer", "day"]),
        CountdownEditorSymbol(id: "moon", title: "Moon", keywords: ["night"]),
        CountdownEditorSymbol(id: "snowflake", title: "Winter", keywords: ["snow", "holiday"]),
        CountdownEditorSymbol(id: "drop", title: "Water", keywords: ["health", "habit"]),
        CountdownEditorSymbol(id: "fork.knife", title: "Dinner", keywords: ["food", "restaurant"]),
        CountdownEditorSymbol(id: "cup.and.saucer", title: "Coffee", keywords: ["drink", "cafe"]),
        CountdownEditorSymbol(id: "cart", title: "Shopping", keywords: ["store", "buy"]),
        CountdownEditorSymbol(id: "creditcard", title: "Payment", keywords: ["money", "bill"]),
        CountdownEditorSymbol(id: "banknote", title: "Money", keywords: ["finance", "budget"]),
        CountdownEditorSymbol(id: "stethoscope", title: "Health", keywords: ["doctor", "medical"]),
        CountdownEditorSymbol(id: "cross.case", title: "Appointment", keywords: ["health", "medical"]),
        CountdownEditorSymbol(id: "wrench.and.screwdriver", title: "Project", keywords: ["tools", "repair"]),
        CountdownEditorSymbol(id: "shippingbox", title: "Delivery", keywords: ["package", "mail"]),
        CountdownEditorSymbol(id: "envelope", title: "Mail", keywords: ["message", "letter"]),
        CountdownEditorSymbol(id: "phone", title: "Call", keywords: ["contact", "meeting"]),
        CountdownEditorSymbol(id: "person.2", title: "People", keywords: ["friends", "family"]),
        CountdownEditorSymbol(id: "person.crop.circle.badge.checkmark", title: "Appointment", keywords: ["person", "meeting"]),
        CountdownEditorSymbol(id: "lock", title: "Secure", keywords: ["private", "deadline"]),
        CountdownEditorSymbol(id: "megaphone", title: "Announcement", keywords: ["launch", "release", "public"]),
        CountdownEditorSymbol(id: "target", title: "Target", keywords: ["goal", "deadline", "focus"]),
        CountdownEditorSymbol(id: "trophy", title: "Trophy", keywords: ["award", "win", "achievement"]),
        CountdownEditorSymbol(id: "medal", title: "Medal", keywords: ["award", "race", "achievement"]),
        CountdownEditorSymbol(id: "rosette", title: "Award", keywords: ["prize", "achievement", "special"]),
        CountdownEditorSymbol(id: "calendar.badge.exclamationmark", title: "Due Date", keywords: ["deadline", "urgent", "important"]),
        CountdownEditorSymbol(id: "exclamationmark.triangle", title: "Important", keywords: ["urgent", "warning", "deadline"]),
        CountdownEditorSymbol(id: "questionmark.circle", title: "Decision", keywords: ["choice", "plan", "review"]),
        CountdownEditorSymbol(id: "lightbulb", title: "Idea", keywords: ["plan", "creative", "project"]),
        CountdownEditorSymbol(id: "hammer", title: "Build", keywords: ["project", "repair", "work"]),
        CountdownEditorSymbol(id: "gearshape", title: "Setup", keywords: ["settings", "configuration", "project"]),
        CountdownEditorSymbol(id: "desktopcomputer", title: "Computer", keywords: ["work", "technology", "setup"]),
        CountdownEditorSymbol(id: "laptopcomputer", title: "Laptop", keywords: ["work", "technology", "computer"]),
        CountdownEditorSymbol(id: "iphone", title: "Phone", keywords: ["device", "mobile", "release"]),
        CountdownEditorSymbol(id: "network", title: "Network", keywords: ["technology", "connection", "launch"]),
        CountdownEditorSymbol(id: "server.rack", title: "Server", keywords: ["technology", "infrastructure", "launch"]),
        CountdownEditorSymbol(id: "house.fill", title: "House", keywords: ["home", "move", "family"]),
        CountdownEditorSymbol(id: "bed.double", title: "Stay", keywords: ["hotel", "travel", "sleep"]),
        CountdownEditorSymbol(id: "airplane.departure", title: "Departure", keywords: ["flight", "travel", "trip"]),
        CountdownEditorSymbol(id: "airplane.arrival", title: "Arrival", keywords: ["flight", "travel", "trip"]),
        CountdownEditorSymbol(id: "map", title: "Map", keywords: ["location", "travel", "place"]),
        CountdownEditorSymbol(id: "beach.umbrella", title: "Vacation", keywords: ["travel", "holiday", "summer"]),
        CountdownEditorSymbol(id: "mountain.2", title: "Outdoors", keywords: ["hike", "nature", "travel"]),
        CountdownEditorSymbol(id: "tree", title: "Tree", keywords: ["nature", "outdoor", "garden"]),
        CountdownEditorSymbol(id: "camera.aperture", title: "Photography", keywords: ["camera", "photo", "shoot"]),
        CountdownEditorSymbol(id: "photo", title: "Photo", keywords: ["picture", "camera", "memory"]),
        CountdownEditorSymbol(id: "paintbrush", title: "Paint", keywords: ["art", "creative", "design"]),
        CountdownEditorSymbol(id: "wand.and.stars", title: "Magic", keywords: ["special", "celebration", "creative"]),
        CountdownEditorSymbol(id: "microphone", title: "Recording", keywords: ["audio", "music", "podcast"]),
        CountdownEditorSymbol(id: "headphones", title: "Listening", keywords: ["music", "audio", "podcast"]),
        CountdownEditorSymbol(id: "ticket", title: "Ticket", keywords: ["event", "show", "concert"]),
        CountdownEditorSymbol(id: "popcorn", title: "Movie Night", keywords: ["film", "cinema", "show"]),
        CountdownEditorSymbol(id: "tv", title: "TV", keywords: ["show", "watch", "release"]),
        CountdownEditorSymbol(id: "baseball", title: "Baseball", keywords: ["sports", "game", "match"]),
        CountdownEditorSymbol(id: "basketball", title: "Basketball", keywords: ["sports", "game", "match"]),
        CountdownEditorSymbol(id: "football", title: "Football", keywords: ["sports", "game", "match"]),
        CountdownEditorSymbol(id: "tennis.racket", title: "Tennis", keywords: ["sports", "game", "match"]),
        CountdownEditorSymbol(id: "figure.walk", title: "Walk", keywords: ["fitness", "health", "exercise"]),
        CountdownEditorSymbol(id: "figure.hiking", title: "Hike", keywords: ["fitness", "outdoor", "travel"]),
        CountdownEditorSymbol(id: "heart.text.square", title: "Checkup", keywords: ["health", "doctor", "medical"]),
        CountdownEditorSymbol(id: "pills", title: "Medicine", keywords: ["health", "medical", "doctor"]),
        CountdownEditorSymbol(id: "bandage", title: "Recovery", keywords: ["health", "medical", "appointment"]),
        CountdownEditorSymbol(id: "pawprint", title: "Pet", keywords: ["animal", "family", "appointment"]),
        CountdownEditorSymbol(id: "cart.badge.plus", title: "Shopping List", keywords: ["shopping", "store", "buy"]),
        CountdownEditorSymbol(id: "bag", title: "Bag", keywords: ["shopping", "store", "gift"]),
        CountdownEditorSymbol(id: "takeoutbag.and.cup.and.straw", title: "Takeout", keywords: ["food", "restaurant", "dinner"]),
        CountdownEditorSymbol(id: "wineglass", title: "Drinks", keywords: ["celebration", "dinner", "party"]),
        CountdownEditorSymbol(id: "leaf.circle", title: "Garden", keywords: ["nature", "plant", "outdoor"]),
        CountdownEditorSymbol(id: "cloud.sun", title: "Weather", keywords: ["outdoor", "day", "travel"]),
        CountdownEditorSymbol(id: "umbrella", title: "Rain", keywords: ["weather", "travel", "outdoor"]),
        CountdownEditorSymbol(id: "shippingbox.fill", title: "Package", keywords: ["delivery", "mail", "order"]),
        CountdownEditorSymbol(id: "tray.full", title: "Inbox", keywords: ["mail", "work", "message"]),
        CountdownEditorSymbol(id: "doc.text", title: "Document", keywords: ["paperwork", "work", "deadline"]),
        CountdownEditorSymbol(id: "signature", title: "Signing", keywords: ["document", "contract", "deadline"]),
        CountdownEditorSymbol(id: "person.3", title: "Group", keywords: ["people", "friends", "family"]),
        CountdownEditorSymbol(id: "figure.2.and.child.holdinghands", title: "Family", keywords: ["people", "home", "child"]),
        CountdownEditorSymbol(id: "graduationcap.fill", title: "Graduation", keywords: ["school", "education", "ceremony"]),
        CountdownEditorSymbol(id: "backpack", title: "School Bag", keywords: ["school", "education", "travel"])
    ]
    private let colorColumns = [GridItem(.adaptive(minimum: 28, maximum: 28), spacing: 12)]
    private let symbolColumns = [GridItem(.adaptive(minimum: 104, maximum: 128), spacing: 8)]

    init(
        mode: CountdownEditorMode,
        suggestedCollectionName: String? = nil,
        onSave: @escaping (CountdownEditorRequest) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel

        switch mode {
        case .createDate:
            _title = State(initialValue: "")
            _targetDate = State(initialValue: Date().addingTimeInterval(60 * 60))
            _colorName = State(initialValue: "blue")
            _symbolName = State(initialValue: "calendar")
            _tags = State(initialValue: [])
            _collectionName = State(initialValue: suggestedCollectionName ?? "")
        case .edit(let snapshot):
            _title = State(initialValue: snapshot.title)
            _targetDate = State(initialValue: max(snapshot.targetDate, Date().addingTimeInterval(60)))
            _colorName = State(initialValue: snapshot.colorName)
            _symbolName = State(initialValue: snapshot.symbolName == "timer" ? "calendar" : snapshot.symbolName)
            _tags = State(initialValue: snapshot.tags)
            _collectionName = State(initialValue: snapshot.collectionName ?? "")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                preview

                field("Title") {
                    TextField("Countdown title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                }

                field("Target") {
                    DatePicker(
                        "",
                        selection: $targetDate,
                        in: Date().addingTimeInterval(1)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                field("Collection") {
                    TextField("Collection name", text: $collectionName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Collection name")
                }

                field("Color") {
                    LazyVGrid(columns: colorColumns, alignment: .leading, spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            colorButton(color)
                        }
                    }
                }

                field("Tags") {
                    VStack(alignment: .leading, spacing: 10) {
                        if tags.isEmpty {
                            Text("No tags")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal) {
                                HStack(spacing: 6) {
                                    ForEach(tags, id: \.self) { tag in
                                        tagButton(tag)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("Add tag", text: $tagDraft)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit(addTagDraft)
                                .onChange(of: tagDraft) {
                                    if tagDraft.contains(",") {
                                        addTagDraft()
                                    }
                                }
                                .accessibilityLabel("Add tag")

                            Button(action: addTagDraft) {
                                Label("Add Tag", systemImage: "plus")
                            }
                            .labelStyle(.iconOnly)
                            .disabled(tagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .help("Add Tag")
                            .accessibilityLabel("Add tag")
                        }
                    }
                }

                field("Symbol") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Search symbols", text: $symbolSearchText)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Search symbols")

                        ScrollView {
                            LazyVGrid(columns: symbolColumns, alignment: .leading, spacing: 8) {
                                ForEach(filteredSymbols) { symbol in
                                    symbolButton(symbol)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                        }
                        .frame(height: 176)
                        .accessibilityLabel("Symbol options")

                        if filteredSymbols.isEmpty {
                            Text("No matching symbols")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(24)

            Divider()

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(CountdownEditorRequest(
                        mode: mode,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        targetDate: targetDate,
                        colorName: colorName,
                        symbolName: symbolName,
                        tags: CountdownTagNormalizer.normalize(tags),
                        collectionName: CountdownCollectionNormalizer.normalize(collectionName)
                    ))
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 520)
    }

    private var preview: some View {
        HStack(spacing: 14) {
            CountdownRingView(
                progress: previewProgress,
                lineWidth: 8,
                accentColor: colorName.countdownColor
            )
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: symbolName)
                        .foregroundStyle(colorName.countdownColor)
                    Text(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Countdown" : title)
                        .font(.headline)
                        .lineLimit(1)
                }

                Text(CountdownFormatter.string(
                    remainingSeconds: max(0, targetDate.timeIntervalSinceNow),
                    precision: .compact
                ))
                .font(.title3.weight(.semibold))
                .monospacedDigit()

                if !tags.isEmpty {
                    FlowTagRow(tags: tags, limit: 4)
                }

                if let collectionName = CountdownCollectionNormalizer.normalize(collectionName) {
                    CountdownTagChip(title: collectionName, systemImage: "folder")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Countdown preview")
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(colorName.countdownColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.title)
                    .font(.title2.bold())
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var headerSubtitle: String {
        switch mode {
        case .createDate:
            "Choose a title and target date."
        case .edit:
            "Update countdown details."
        }
    }

    private var filteredSymbols: [CountdownEditorSymbol] {
        let query = symbolSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return symbols.filter { $0.matches(query) }
    }

    private var previewProgress: Double {
        let duration = max(targetDate.timeIntervalSince(Date()), 1)
        return CountdownCalculator.progress(
            remainingSeconds: duration,
            originalDurationSeconds: duration
        )
    }

    private func field<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func colorButton(_ color: String) -> some View {
        Button {
            colorName = color
        } label: {
            Circle()
                .fill(color.countdownColor)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(colorName == color ? Color.primary : Color.secondary.opacity(0.28), lineWidth: colorName == color ? 2 : 1)
                }
                .overlay {
                    if colorName == color {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(color.capitalized)
        .accessibilityLabel(color.capitalized)
        .accessibilityAddTraits(colorName == color ? .isSelected : [])
    }

    private func symbolButton(_ symbol: CountdownEditorSymbol) -> some View {
        Button {
            symbolName = symbol.id
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol.id)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(symbolName == symbol.id ? Color.accentColor : Color.primary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 0) {
                    Text(symbol.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(symbol.id)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if symbolName == symbol.id {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 42)
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(symbolName == symbol.id ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(symbolName == symbol.id ? Color.accentColor : Color.secondary.opacity(0.14), lineWidth: symbolName == symbol.id ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .help(symbol.title)
        .accessibilityLabel(symbol.title)
        .accessibilityAddTraits(symbolName == symbol.id ? .isSelected : [])
    }

    private func tagButton(_ tag: String) -> some View {
        Button {
            tags.removeAll { CountdownTagNormalizer.key(for: $0) == CountdownTagNormalizer.key(for: tag) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "tag")
                Text(tag)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Remove \(tag)")
        .accessibilityLabel("Remove \(tag)")
    }

    private func addTagDraft() {
        let parts = tagDraft
            .split(separator: ",")
            .map(String.init)
        tags = CountdownTagNormalizer.normalize(tags + parts)
        tagDraft = ""
    }
}
