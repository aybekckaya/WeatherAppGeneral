//
//  MainViewModel.swift
//  WeatherApp
//
//  Created by Aybek Can Kaya on 2.07.2021.
//

import Foundation
import SwiftLocation
import CoreLocation
import Combine

// MARK: - WeatherTableItem
enum WeatherTableItem {
    case cityInfo
    case weatherInfo
    case nextDay
    case hourlyInfo
    case sunDetail
    case windDetail
    
    var height: CGFloat {
        switch self {
        case .cityInfo: return 60
        case .weatherInfo: return 206
        case .nextDay: return 98
        case .hourlyInfo: return 200
        case .sunDetail, .windDetail: return 200
        }
    }
}

// MARK: - List View Data
struct ListViewData {
    let dayName: String
    let icon: String
    let degree: String
    let windSpeed: String
    let humidity: String
    let pressure: String
    let windDegree: String
}

struct WeatherViewData {
    let cityName : String
    let countryName : String
    let weatherState : String
    let weatherDegree : String
    let weatherIcon : String
    let sunriseValue : String
    let sunsetValue : String
    let windSpeedValue : String
    let groundLevelValue : String
    let pressureValue : String
    let seeLevelValue : String
    let humudityVaalue : String
}



// MARK: Main View Model {Class}
class MainViewModel {
    
    private let dataLayer = DataLayer()
    
    private(set) var city: City!
    private(set) var dailyWeather: [Date: [List]] = [:] // Günlük olarak bölünmüş dictionary
    private(set) var currentHourlyWeatherData: [List] = []
    private(set) var currentWeather: List!
    private(set) var arrListViewData: [ListViewData] = []
  
    private(set) var shouldUpdateTableView = PassthroughSubject<Void, Never>()
    private(set) var shouldShowAlertViewForError = PassthroughSubject<WeatherAppError, Never>()
    private(set) var shouldNavigateToDaysViewController = PassthroughSubject<Void, Never>()
    private(set) var shouldShowLoadingAnimation = CurrentValueSubject<Bool, Never>(false)
    
    private var cancellables = Set<AnyCancellable>()
    
    private(set) var arrItems: [WeatherTableItem] = []
    
    // MARK: - Getters
    var cityName: String {
        return city.name
    }
    
    var countryName: String {
        return city.country
    }
    
    var weatherState: String {
        guard let weather = currentWeather.weather.first else { return "" }
        return weather.description.capitalized
    }
    
    var weatherDegree: String {
        guard let main = currentWeather.main else { return "" }
        return "\(main.temp)"
    }
    
    var weatherIcon: String {
        guard let weather = currentWeather.weather.first else { return "" }
        return weather.icon.convertToIconName()
    }
    
    var sunriseValue: String {
        return "".sunriseAndSunsetValue(value: Int(self.city.sunrise))
    }
    
    var sunsetValue: String {
        return "".sunriseAndSunsetValue(value: Int(self.city.sunset))
    }
    
    var windSpeedValue: String {
        return "\(currentWeather.wind.speed) km/h"
    }

    var windDegreeValue: String {
        return "\(currentWeather.wind.deg) °"
    }
    
    var groundLevelValue : String {
        return "\(currentWeather.main!.grnd_level)"
    }
    
    var pressureValue : String {
        return "\(currentWeather.main!.pressure) hPa"
    }
    
    var seeLevelValue : String {
        return "\(currentWeather.main!.sea_level) MSL"
    }
    
    var humudityVaalue : String {
        return "\(currentWeather.main!.humidity) g/m3"
    }

    init() {
        addListeners()
    }
    
    deinit {
        self.cancellables.forEach { $0.cancel() }
    }
}

// MARK: - Public
extension MainViewModel {
   @objc func initialize() {
        self.shouldShowLoadingAnimation.send(true)
        let publisher = self.findUserCoordinates().flatMap { coordinates -> AnyPublisher<WeatherModel?, Never> in
            guard let coord = coordinates else { return Just(nil).eraseToAnyPublisher() }
            return self.requestWeatherInfo(coordinates: coord)
        }.flatMap { model -> AnyPublisher<Bool, Never> in
            guard let md = model else { return Just(true).eraseToAnyPublisher() }
            return self.processResponse(md)
        }
        
        self.shouldUpdateTableView.send()
        publisher.sink { _ in
            self.shouldUpdateTableView.send()
            self.shouldShowLoadingAnimation.send(false)
        }.store(in: &cancellables)
    }
    
    func initializeListViewItems() {
        let publisher = self.convertListModelsToListDatas()
        
        publisher.sink { listArr in
            self.arrListViewData = listArr
            self.shouldUpdateTableView.send()
        }.store(in: &cancellables)
    }
    
    func nextFiveDaysDidTapped() {
        self.shouldNavigateToDaysViewController.send()
    }
    
    func getTodayForecastList() -> [List] {
        return self.currentHourlyWeatherData
    }
    
    func isCurrentForecastTimeModel(timeForecast: List) -> Bool {
        let currentForecastTime = currentWeather.date()
        let listForecastTime = timeForecast.date()
        return listForecastTime == currentForecastTime
    }
    
    func updateCurrentWeather(_ list: List) {
        self.currentWeather = list
        self.shouldUpdateTableView.send()
    }
    
    
    
}

// MARK: - API Request
extension MainViewModel {
    private func requestWeatherInfo(coordinates: CLLocationCoordinate2D) ->AnyPublisher<WeatherModel?, Never> {
        if Network.shared.networkStatus.value == .offline {
            self.shouldShowAlertViewForError.send(WeatherAppError.noInternetConnection)
        }
        return self.dataLayer.requestWeatherData(latitude: coordinates.latitude, longitude: coordinates.longitude).flatMap { weatherData -> AnyPublisher<WeatherModel?, Never> in
            guard let weatherData = weatherData else {
                // TODO: Show Error
                return Just(nil).eraseToAnyPublisher()
            }
            do {
                let model = try JSONDecoder().decode(WeatherModel.self, from: weatherData)
                return Just(model).eraseToAnyPublisher()
            } catch let jsonError {
                self.shouldShowAlertViewForError.send(.apiDataNotFound)
                return Just(nil).eraseToAnyPublisher()
            }
        }.eraseToAnyPublisher()
    }
    
    private func processResponse(_ response: WeatherModel) -> AnyPublisher<Bool, Never> {
        guard let city = response.city, let weatherData = response.list else {
            self.shouldShowAlertViewForError.send(.apiDataNotFound)
            return Just(true).eraseToAnyPublisher()
        }
        
        let sortedWeatherData = weatherData.sorted { (we1, we2) -> Bool in
            let date1 = Date(timeIntervalSince1970: TimeInterval(we1.dt!))
            let date2 = Date(timeIntervalSince1970: TimeInterval(we2.dt!))
            return date1 < date2
        }
        self.currentHourlyWeatherData = Array(sortedWeatherData[0 ..< C.App.numberOfItemsInHourlyCollectionView])
        
        var dct: [String: [List]] = [:]
        self.dailyWeather = [:]
        weatherData.forEach { weather in
            let interval = TimeInterval(weather.dt!)
            let date = Date(timeIntervalSince1970: interval)
            let calendarDate = Calendar.current.dateComponents([.day, .year, .month], from: date)
            let identifier = "\(calendarDate.day!)-\(calendarDate.month!)-\(calendarDate.year!)"
            let dayDate = self.dateFrom(day: calendarDate.day!, month: calendarDate.month!, year: calendarDate.year!)
            if dct.keys.contains(identifier) {
                var arr = dct[identifier]!
                arr.append(weather)
                dct[identifier] = arr
                var arrDateDct = self.dailyWeather[dayDate]!
                arrDateDct.append(weather)
                self.dailyWeather[dayDate] = arrDateDct
            } else {
                dct[identifier] = [weather]
                self.dailyWeather[dayDate] = [weather]
            }
        }
        
        self.dailyWeather.forEach { (key , value) in
            print("\(key)->\(value)")
        }
        
        self.currentWeather = sortedWeatherData.first!
        self.city = city
        
        self.arrItems = [.cityInfo, .weatherInfo, .nextDay, .hourlyInfo, .sunDetail, .windDetail]
        
        return Just(true).eraseToAnyPublisher()
    }
    
    private func dateFrom(day: Int, month: Int, year: Int) -> Date {
        var components = DateComponents()
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.day = day
        components.month = month
        components.year = year
        let date = Calendar.current.date(from: components)
        return date!
    }
}

// MARK: - User Location
extension MainViewModel {
    private func findUserCoordinates() -> AnyPublisher<CLLocationCoordinate2D? , Never> {
        return Future { promise in
            SwiftLocation.gpsLocationWith {
                $0.subscription = .single
                $0.accuracy = .neighborhood
            }.then { result in // you can attach one or more subscriptions via `then`.
                switch result {
                case .success(let newData):
                    promise(.success(newData.coordinate))
                case .failure(let error):
                    self.shouldShowAlertViewForError.send(.locationNotFound)
                    promise(.success(nil))
                }
            }
        }.eraseToAnyPublisher()
    }
}

// MARK: - Listeners
extension MainViewModel {
    private func addListeners() {
        dataLayer.shouldShowError.receive(on: DispatchQueue.main).sink { err in
            self.shouldShowAlertViewForError.send(err)
        }.store(in: &cancellables)
    }
}

//MARK: -MainViewController
//extension MainViewModel {
//    private func convertWeatherModelToWeatherDatas() -> AnyPublisher<[WeatherViewData],Never>{
//        guard  let main = model.main  else { return nil}
//        let cityName = model
//
//        }
//
//    }
//}

// MARK: - DaysViewController
extension MainViewModel {
    private func convertListModelsToListDatas() -> AnyPublisher<[ListViewData], Never> {
        return self.convertWeatherDictionaryToListArrayRx()
            .flatMap { listModels -> AnyPublisher<[ListViewData], Never> in
                let viewDatas = listModels.compactMap { model -> ListViewData? in
                    guard let main = model.main else { return nil }
                    let dayName = model.date().nameOfTheDay
                    let icon = model.weatherIcon()
                    let degree = "\(main.temp) °C"
                    let windSpeed = "\(model.wind.speed) km/h"
                    let humidity = "\(main.humidity) g/m3"
                    let pressure = "\(main.pressure) hPa"
                    let windDegree = "\(model.wind.deg) °"
                    let viewData = ListViewData(dayName: dayName, icon: icon, degree: degree, windSpeed: windSpeed, humidity: humidity, pressure: pressure, windDegree: windDegree)
                    return viewData
                }
                return Just(viewDatas).eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }
    
    private func convertWeatherDictionaryToListArrayRx() -> AnyPublisher<[List], Never> {
        return Future { promise in
            DispatchQueue.global().async {
                let listArr = self.convertWeatherDictionaryToListArray()
                promise(.success(listArr))
            }
        }.eraseToAnyPublisher()
    }
    
    private func convertWeatherDictionaryToListArray() -> [List] {
        let sortedKeys = Array(self.dailyWeather.keys).sorted { (date1, date2) -> Bool in
            return date1 < date2
        }
        
        var arrWeatherListData: [List] = []
        for key in sortedKeys {
            let currentList = self.dailyWeather[key]!
            if currentList.count > 0 {
                let sortedListItems = currentList.sorted { (list1, list2) -> Bool in
                    return list1.date() < list2.date()
                }
                let currentItem = sortedListItems[sortedListItems.count/2]
                arrWeatherListData.append(currentItem)
            }
        }
        
//        arrWeatherListData.forEach {
//            print("Weather: \($0.date()) : \($0)")
//        }
        return arrWeatherListData
    }
}
