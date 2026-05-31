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
}

private struct CountdownEditorSymbol: Identifiable {
    let id: String
    let title: String
}

struct CountdownEditorView: View {
    let mode: CountdownEditorMode
    let onSave: (CountdownEditorRequest) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var targetDate: Date
    @State private var colorName: String
    @State private var symbolName: String

    private let colors = ["blue", "indigo", "purple", "pink", "red", "orange", "yellow", "green", "mint", "teal", "cyan", "brown", "gray"]
    private let symbols = [
        CountdownEditorSymbol(id: "calendar", title: "Calendar"),
        CountdownEditorSymbol(id: "timer", title: "Timer"),
        CountdownEditorSymbol(id: "hourglass", title: "Hourglass"),
        CountdownEditorSymbol(id: "flag.checkered", title: "Goal"),
        CountdownEditorSymbol(id: "bell", title: "Reminder"),
        CountdownEditorSymbol(id: "alarm", title: "Alarm"),
        CountdownEditorSymbol(id: "birthday.cake", title: "Birthday"),
        CountdownEditorSymbol(id: "gift", title: "Gift"),
        CountdownEditorSymbol(id: "sparkles", title: "Special"),
        CountdownEditorSymbol(id: "star", title: "Star"),
        CountdownEditorSymbol(id: "heart", title: "Heart"),
        CountdownEditorSymbol(id: "briefcase", title: "Work"),
        CountdownEditorSymbol(id: "graduationcap", title: "School"),
        CountdownEditorSymbol(id: "book", title: "Reading"),
        CountdownEditorSymbol(id: "airplane", title: "Travel"),
        CountdownEditorSymbol(id: "car", title: "Car"),
        CountdownEditorSymbol(id: "bicycle", title: "Bike"),
        CountdownEditorSymbol(id: "tram", title: "Transit"),
        CountdownEditorSymbol(id: "mappin.and.ellipse", title: "Location"),
        CountdownEditorSymbol(id: "globe", title: "World"),
        CountdownEditorSymbol(id: "house", title: "Home"),
        CountdownEditorSymbol(id: "building.2", title: "Office"),
        CountdownEditorSymbol(id: "sportscourt", title: "Sports"),
        CountdownEditorSymbol(id: "dumbbell", title: "Workout"),
        CountdownEditorSymbol(id: "gamecontroller", title: "Gaming"),
        CountdownEditorSymbol(id: "music.note", title: "Music"),
        CountdownEditorSymbol(id: "film", title: "Film"),
        CountdownEditorSymbol(id: "camera", title: "Camera"),
        CountdownEditorSymbol(id: "bolt", title: "Energy"),
        CountdownEditorSymbol(id: "leaf", title: "Nature"),
        CountdownEditorSymbol(id: "pawprint", title: "Pets")
    ]
    private let symbolColumns = Array(repeating: GridItem(.fixed(40), spacing: 8), count: 7)

    init(
        mode: CountdownEditorMode,
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
        case .edit(let snapshot):
            _title = State(initialValue: snapshot.title)
            _targetDate = State(initialValue: max(snapshot.targetDate, Date().addingTimeInterval(60)))
            _colorName = State(initialValue: snapshot.colorName)
            _symbolName = State(initialValue: snapshot.symbolName == "timer" ? "calendar" : snapshot.symbolName)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            VStack(alignment: .leading, spacing: 18) {
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

                field("Color") {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            colorButton(color)
                        }
                    }
                }

                field("Symbol") {
                    LazyVGrid(columns: symbolColumns, alignment: .leading, spacing: 8) {
                        ForEach(symbols) { symbol in
                            symbolButton(symbol)
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
                        symbolName: symbolName
                    ))
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 460)
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
            Image(systemName: symbol.id)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 34)
                .foregroundStyle(symbolName == symbol.id ? Color.accentColor : Color.primary)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(symbolName == symbol.id ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(symbolName == symbol.id ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: symbolName == symbol.id ? 2 : 1)
                }
        }
        .buttonStyle(.plain)
        .help(symbol.title)
        .accessibilityLabel(symbol.title)
        .accessibilityAddTraits(symbolName == symbol.id ? .isSelected : [])
    }
}

