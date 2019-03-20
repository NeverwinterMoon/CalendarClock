//
//  File.swift
//  CalendarClock
//
//  Created by Mookyung Kwak on 2019-02-17.
//  Copyright © 2019 Mookyung Kwak. All rights reserved.
//

import Foundation
import ReactorKit
import RxSwift
import RxCocoa
import EventKit

class ViewReactor: Reactor {

    enum Action {
        case startClicking
        case fetchEvents
        case observeEvents
        case fetchCurrentWeather
        case fetchFutureWeather
        case observeFirstCurrentWeather
        case observeFirstFutureWeather
    }
    
    enum Mutation {
        case clicks
        case receiveEvents([CustomEvent])
        case receiveCurrentWeathers(CustomWeather)
        case receiveFutureWeathers([CustomWeather])
    }
    
    struct State {
        var currentTime: String?
        var events: [SectionedEvents]?
        var weathers: CustomWeather? // description, icon, temp
        var futures: [SectionedWeathers]?
    }
    
    let initialState: State
    let eventStore = EventStore()
    let weather = Weather()
    
    init() {
        print("init clock view reactor")
        self.initialState = State()
    }
    
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .startClicking:
            return Observable<Int>.interval(1, scheduler: MainScheduler.instance)
                .map { _ in Mutation.clicks }
            
        case .fetchEvents: // interval : 1 minute = 60 seconds (considering clock changes every 1 minute)
            return Observable<Int>.interval(60, scheduler: MainScheduler.instance)
                .startWith(11) // to start immediately
                .flatMap { _ in self.eventStore.authorized.asObservable() }
                .filter { $0 == true }
                .map { _ in self.eventStore.reset() }
                .flatMap { _ in self.eventStore.fetchEventsDetail() }
                .map { Mutation.receiveEvents($0) }
            
        case .observeEvents:
            return NotificationCenter.default.rx.notification(.EKEventStoreChanged)
                .flatMap { _ in self.eventStore.fetchEventsDetail() }
                .map { Mutation.receiveEvents($0) }
            
        case .fetchCurrentWeather: // interval : 1 hour = 3600 seconds
            return Observable<Int>.interval(3600, scheduler: MainScheduler.instance)
                .startWith(11) // to start immediately
                .filter { _ in self.weather.coord.0 > 0 }
                .flatMap { _ in self.weather.fetchCurrentWeatherData() }
                .map { Mutation.receiveCurrentWeathers($0) }
            
        case .fetchFutureWeather: // interval : 2 hour = 7200 seconds
            return Observable<Int>.interval(7200, scheduler: MainScheduler.instance)
                .startWith(11) // to start immediately
                .filter { _ in self.weather.coord.0 > 0 }
                .flatMap { _ in self.weather.fetchFutureWeatherData() }
                .map { Mutation.receiveFutureWeathers($0) }
            
        case .observeFirstCurrentWeather:
            return self.weather.locationJustFetched.asObservable()
                .flatMap { _ in self.weather.fetchCurrentWeatherData() }
                .map { Mutation.receiveCurrentWeathers($0) }
        
        case .observeFirstFutureWeather:
            return self.weather.locationJustFetched.asObservable()
                .flatMap { _ in self.weather.fetchFutureWeatherData() }
                .map { Mutation.receiveFutureWeathers($0) }
            
        }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        switch mutation {
        case .clicks:
            var newState = state
            newState.currentTime = Clock.currentDateString()
            return newState
        case let .receiveEvents(events):
            //print("request events : ", events!.description)
            var newState = state
            let sectionedEvents = SectionedEvents(header: "something", items: events)
            print(sectionedEvents.items.description)
            newState.events = [sectionedEvents]
            return newState
        case let .receiveCurrentWeathers(weathers):
            var newState = state
            print("received current : ", weathers)
            newState.weathers = weathers
            return newState
        case let .receiveFutureWeathers(weathers):
            var newState = state
            let filtered = weathers.filter { $0.time != nil }
            let sectionedWeathers = SectionedWeathers(header: "something", items: filtered)
            print("received futures : ", sectionedWeathers.items.description)
            newState.futures = [sectionedWeathers]
            return newState
        }
    }
    
    func requestLocationAuthorization() {
        self.weather.verifyAuthorization()
    }
    
    func requestEventAuthorization() {
        self.eventStore.verifyAuthorityToEvents()
    }
}
