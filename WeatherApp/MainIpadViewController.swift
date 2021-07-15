//
//  MainIpadViewController.swift
//  WeatherApp
//
//  Created by Aybek Can Kaya on 5.07.2021.
//

import UIKit
import Combine

class MainIpadViewController: UIViewController {
    
    @IBOutlet var mainIpadView: UIView!
    @IBOutlet weak var viewContainerWeatherDataCollectionView: UIView!
    @IBOutlet weak var viewContainerDayTableView: UIView!
    @IBOutlet weak var viewContainerHourTableView: UIView!
    @IBOutlet weak var hourTableViewContainerHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var imViewIcon: UIImageView!
    @IBOutlet weak var lblWeatherState: UILabel!
    @IBOutlet weak var lblDegree: UILabel!
    @IBOutlet weak var lblCity: UILabel!
    
    @IBOutlet weak var btnRefresh: UIButton!
    @IBOutlet weak var lblCelcius: UILabel!
    private var dayTableVC: DayTableViewController!
    private var hourTableVC: HourTableViewController!
    private var weatherDataCollectionVC: WeatherDataCollectionView!

    private let viewModel = MainViewModel()
    
    private var cancellables = Set<AnyCancellable>()
    
    @IBAction func btnRefreshClicked(_ sender: Any) {
        self.viewModel.initializeForIpad()
    }
    
    
}

// MARK: - Lifecycle
extension MainIpadViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        addListeners()
        viewModel.initializeForIpad()
    }
}

// MARK: - Set Up UI
extension MainIpadViewController {
    private func setUpUI() {
      //  self.mainIpadView.backgroundColor  = C.Color.viewControllerBackgroundColor
//        let largeConfig = UIImage.SymbolConfiguration(pointSize: size, weight: .bold, scale: .large)
//
//        let largeBoldDoc = UIImage(systemName: "doc.circle.fill", withConfiguration: largeConfig)
//
//        button.setImage(largeBoldDoc, for: .normal)
//
        
        
        var sizeWidth = self.view.frame.size.width * 20 / 1024
        print(sizeWidth)
        
        let largeConfig = UIImage.SymbolConfiguration(pointSize: sizeWidth)
        let largeDoc = UIImage(systemName: "arrow.2.circlepath", withConfiguration: largeConfig)
        btnRefresh.setImage(largeDoc, for: .normal)
        
        print(self.view.frame.width)
        
        self.children.forEach { childVC in
            if let viewController = childVC as? DayTableViewController {
                self.dayTableVC = viewController
                dayTableVC.setViewModel(self.viewModel)
            } else if let viewController = childVC as? HourTableViewController {
                self.hourTableVC = viewController
                hourTableVC.setViewModel(self.viewModel)
            } else if let viewController = childVC as? WeatherDataCollectionView {
                self.weatherDataCollectionVC = viewController
                weatherDataCollectionVC.setViewModel(self.viewModel)
            }
        }
        updateWeatherInfoUI()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
       
      updateWeatherInfoUI()
        
    }
}

// MARK: - Update Info
extension MainIpadViewController {
    private func updateWeatherInfoUI() {
        
        self.mainIpadView.backgroundColor  = C.Color.viewControllerBackgroundColor
        self.lblCity.textColor = C.Color.cityInfoTitleColor
        self.lblDegree.textColor = C.Color.labelDegreeColor
        self.lblWeatherState.textColor = C.Color.labelStateColor
        self.imViewIcon.tintColor = C.Color.imageIconInfo
        self.lblCelcius.textColor = C.Color.labelDegreeColor
        
        self.viewContainerDayTableView.backgroundColor = C.Color.ipadViewContainerBackgroundColor
        self.viewContainerHourTableView.backgroundColor = C.Color.ipadViewContainerBackgroundColor
        self.viewContainerWeatherDataCollectionView.backgroundColor = C.Color.ipadViewContainerBackgroundColor
       
        self.viewContainerHourTableView.layer.cornerRadius = 20
        self.viewContainerWeatherDataCollectionView.layer.cornerRadius = 20
      
        self.viewContainerHourTableView.containerShadow()
        self.viewContainerDayTableView.containerShadow()
        self.viewContainerWeatherDataCollectionView.containerShadow()
        
        guard self.viewModel.currentWeatherViewData != nil else { return }
        self.lblCity.text = self.viewModel.currentWeatherViewData.locationText
        self.lblDegree.text = self.viewModel.currentWeatherViewData.weatherDegree
        self.imViewIcon.image = UIImage(systemName: viewModel.currentWeatherViewData.weatherIcon)
        self.lblWeatherState.text = self.viewModel.currentWeatherViewData.weatherState
        
        
        
    }
}

// MARK: - Listeners
extension MainIpadViewController {
    private func addListeners() {
        Network.shared.networkStatus.receive(on: DispatchQueue.main).sink { status in
            print("Current Status: \(status)")
            if status == .offline{
                ToastView.show(with: "No internet connection !")
            }
        }.store(in: &cancellables)
        
        viewModel.shouldShowAlertViewForError.receive(on: DispatchQueue.main).sink { error in
            if error == .noInternetConnection {
                ToastView.show(with: "No internet connection !")
            }
        }.store(in: &cancellables)
        
        viewModel.shouldShowLoadingAnimation
            .receive(on: DispatchQueue.main)
            .sink { show in
            show ? LoadingView.show() : LoadingView.hide()
        }.store(in: &cancellables)
        
        viewModel.shouldUpdateTableView
            .receive(on: DispatchQueue.main)
            .sink { _ in
                self.updateWeatherInfoUI()
                self.hourTableViewContainerHeightConstraint.constant = CGFloat(88 * self.viewModel.currentWeatherHourlyDataViews.count)
                self.view.layoutIfNeeded()
        }.store(in: &cancellables)
    }
}
