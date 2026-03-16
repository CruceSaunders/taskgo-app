import Foundation
import FirebaseAuth
import Combine

struct WeekDaySummary: Identifiable {
    let id: String          // date string
    let date: Date
    let dayLabel: String    // "Mon", "Tue", etc.
    let activeMinutes: Int
    let totalInputs: Int
    let isSelected: Bool
}

class ActivityViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var currentDay: ActivityDay?
    @Published var zoomLevel: Double = 60
    @Published var visibleSeries: Set<DataSeries> = Set(DataSeries.allCases)
    @Published var chartData: [ChartDataPoint] = []
    @Published var isLoading = false
    @Published var isTrackingActive = false
    @Published var eventsFlowing = false
    @Published var weekSummary: [WeekDaySummary] = []
    @Published var permissionState: ActivityTracker.PermissionState = .unknown
    @Published var keyboardHealthy = true
    @Published var sttAppsDetected: [String] = []

    static let zoomSteps: [Double] = [1, 5, 15, 30, 60]

    private var cancellables = Set<AnyCancellable>()

    init() {
        Publishers.CombineLatest3($currentDay, $zoomLevel, $visibleSeries)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] day, zoom, series in
                self?.recomputeChartData(day: day, zoom: zoom, series: series)
            }
            .store(in: &cancellables)

        ActivityTracker.shared.$isTracking
            .receive(on: DispatchQueue.main)
            .assign(to: &$isTrackingActive)

        ActivityTracker.shared.$eventsAreFlowing
            .receive(on: DispatchQueue.main)
            .assign(to: &$eventsFlowing)

        ActivityTracker.shared.$permissionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$permissionState)

        ActivityTracker.shared.$keyboardHealthy
            .receive(on: DispatchQueue.main)
            .assign(to: &$keyboardHealthy)

        ActivityTracker.shared.$sttAppsDetected
            .receive(on: DispatchQueue.main)
            .assign(to: &$sttAppsDetected)

        ActivityTracker.shared.$todayData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newData in
                guard let self = self, self.isToday else { return }
                self.currentDay = newData
            }
            .store(in: &cancellables)
    }

    var showPermissionBanner: Bool {
        permissionState == .denied
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var snappedZoomLevel: Double {
        Self.zoomSteps.min(by: { abs($0 - zoomLevel) < abs($1 - zoomLevel) }) ?? 60
    }

    var zoomLabel: String {
        let snapped = Int(snappedZoomLevel)
        if snapped >= 60 { return "1 hour" }
        return "\(snapped) min"
    }

    // MARK: - Data Loading

    func loadSelectedDate() {
        let date = selectedDate
        if isToday {
            currentDay = ActivityTracker.shared.todayData
            loadWeekSummary()
            return
        }

        isLoading = true

        if let local = ActivityTracker.shared.loadDay(date: date) {
            currentDay = local
            isLoading = false
            loadWeekSummary()
            return
        }

        guard let userId = Auth.auth().currentUser?.uid else {
            currentDay = nil
            isLoading = false
            loadWeekSummary()
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        Task { @MainActor in
            do {
                let day = try await FirestoreService.shared.getActivityDay(userId: userId, dateString: dateString)
                self.currentDay = day
            } catch {
                self.currentDay = nil
            }
            self.isLoading = false
            self.loadWeekSummary()
        }
    }

    func goToPreviousDay() {
        guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = prev
        loadSelectedDate()
    }

    func goToNextDay() {
        guard !isToday else { return }
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = next
        loadSelectedDate()
    }

    func goToToday() {
        selectedDate = Date()
        loadSelectedDate()
    }

    func selectDay(_ date: Date) {
        selectedDate = date
        loadSelectedDate()
    }

    // MARK: - Week Summary

    private func loadWeekSummary() {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: selectedDate)
        let mondayOffset = (weekday == 1) ? -6 : (2 - weekday)
        guard let monday = calendar.date(byAdding: .day, value: mondayOffset, to: selectedDate) else { return }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        let idFormatter = DateFormatter()
        idFormatter.dateFormat = "yyyy-MM-dd"

        var summaries: [WeekDaySummary] = []
        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: i, to: monday) else { continue }
            let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
            let isFuture = day > Date()

            var activeMinutes = 0
            var totalInputs = 0

            if !isFuture {
                if calendar.isDateInToday(day) {
                    activeMinutes = ActivityTracker.shared.todayData.totalActiveMinutes
                    totalInputs = ActivityTracker.shared.todayData.totalInputs
                } else if let loaded = ActivityTracker.shared.loadDay(date: day) {
                    activeMinutes = loaded.totalActiveMinutes
                    totalInputs = loaded.totalInputs
                }
            }

            summaries.append(WeekDaySummary(
                id: idFormatter.string(from: day),
                date: day,
                dayLabel: dayFormatter.string(from: day),
                activeMinutes: activeMinutes,
                totalInputs: totalInputs,
                isSelected: isSelected
            ))
        }
        weekSummary = summaries
    }

    // MARK: - Chart Data

    private func recomputeChartData(day: ActivityDay?, zoom: Double, series: Set<DataSeries>) {
        guard let day = day else {
            chartData = []
            return
        }

        let bucketSize = Int(snappedZoomLevel)
        let totalBuckets = 1440 / bucketSize

        var points: [ChartDataPoint] = []
        let hourFmt = DateFormatter()
        hourFmt.dateFormat = "h a"
        let minFmt = DateFormatter()
        minFmt.dateFormat = "h:mm"

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day.date)

        for bucket in 0..<totalBuckets {
            let bucketStart = bucket * bucketSize
            let bucketEnd = bucketStart + bucketSize
            let entriesInBucket = day.minuteData.filter { $0.minute >= bucketStart && $0.minute < bucketEnd }

            let labelDate = calendar.date(byAdding: .minute, value: bucketStart, to: startOfDay) ?? startOfDay
            let label = bucketSize >= 60 ? hourFmt.string(from: labelDate) : minFmt.string(from: labelDate)

            for s in series.sorted(by: { $0.rawValue < $1.rawValue }) {
                let value: Int
                if bucketSize == 60, bucketStart / 60 < day.hourlySummary.count {
                    value = day.hourlySummary[bucketStart / 60].value(for: s)
                } else {
                    value = entriesInBucket.reduce(0) { $0 + $1.value(for: s) }
                }
                points.append(ChartDataPoint(
                    bucketStart: bucketStart, bucketEnd: bucketEnd,
                    series: s, value: value, label: label
                ))
            }
        }
        chartData = points
    }

    // MARK: - Summary Helpers

    var totalActiveTime: String {
        guard let day = currentDay else { return "0m" }
        let mins = day.totalActiveMinutes
        if mins >= 60 { return "\(mins / 60)h \(mins % 60)m" }
        return "\(mins)m"
    }

    var idleMinutes: Int {
        guard let day = currentDay,
              let first = day.firstActivity,
              let last = day.lastActivity else { return 0 }
        let totalSpan = max(1, Int(last.timeIntervalSince(first) / 60))
        return max(0, totalSpan - day.totalActiveMinutes)
    }

    var totalKeystrokes: Int { currentDay?.totalKeyboard ?? 0 }
    var totalClicks: Int { currentDay?.totalClicks ?? 0 }
    var totalScrolls: Int { currentDay?.totalScrolls ?? 0 }
    var totalMovements: Int { currentDay?.totalMovement ?? 0 }
    var totalInputs: Int { currentDay?.totalInputs ?? 0 }
    var totalDictation: Int { currentDay?.totalDictation ?? 0 }
    var meaningfulInputs: Int { currentDay?.meaningfulInputs ?? 0 }
    var engagedMinutes: Int { currentDay?.engagedMinutes ?? 0 }

    var engagedTime: String {
        let mins = engagedMinutes
        if mins >= 60 { return "\(mins / 60)h \(mins % 60)m" }
        return "\(mins)m"
    }

    var averageInputsPerActiveMinute: Int {
        guard let day = currentDay, day.totalActiveMinutes > 0 else { return 0 }
        return day.meaningfulInputs / day.totalActiveMinutes
    }

    var firstActivityTime: String? {
        guard let first = currentDay?.firstActivity else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: first)
    }

    var lastActivityTime: String? {
        guard let last = currentDay?.lastActivity else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: last)
    }

    var displayDateString: String {
        if isToday { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }
}
