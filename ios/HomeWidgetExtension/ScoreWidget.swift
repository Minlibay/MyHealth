// Виджет WidgetKit со скорами Здоровье / Сон / Восстановление.
//
// ВАЖНО: этот файл НЕ подключён к сборке — таргет Widget Extension
// создаётся только в Xcode (см. README.md рядом). После создания таргета
// добавьте этот файл в него и удалите автосгенерированный шаблон.

import WidgetKit
import SwiftUI

private let appGroup = "group.com.myhealthv.app"

struct ScoreEntry: TimelineEntry {
    let date: Date
    let health: String
    let sleep: String
    let recovery: String
}

struct ScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScoreEntry {
        ScoreEntry(date: Date(), health: "82", sleep: "76", recovery: "88")
    }

    func getSnapshot(in context: Context, completion: @escaping (ScoreEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScoreEntry>) -> Void) {
        // Данные пишет Flutter (home_widget) в UserDefaults app group.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [load()], policy: .after(next)))
    }

    private func load() -> ScoreEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        return ScoreEntry(
            date: Date(),
            health: defaults?.string(forKey: "health") ?? "—",
            sleep: defaults?.string(forKey: "sleep") ?? "—",
            recovery: defaults?.string(forKey: "recovery") ?? "—"
        )
    }
}

struct ScoreWidgetView: View {
    let entry: ScoreEntry

    var body: some View {
        HStack {
            score(entry.health, "Здоровье")
            score(entry.sleep, "Сон")
            score(entry.recovery, "Восстан.")
        }
        .containerBackground(.background, for: .widget)
    }

    private func score(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.title).bold()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

@main
struct ScoreWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScoreWidget", provider: ScoreProvider()) { entry in
            ScoreWidgetView(entry: entry)
        }
        .configurationDisplayName("MyHealth")
        .description("Скоры здоровья, сна и восстановления.")
        .supportedFamilies([.systemMedium])
    }
}
