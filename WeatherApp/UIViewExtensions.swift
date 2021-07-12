//
//  UIViewExtensions.swift
//  WeatherApp
//
//  Created by Aybek Can Kaya on 7.07.2021.
//

import Foundation
import UIKit


extension UIView {
    func addItemShadow() {
        self.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        self.layer.shadowOpacity = 1
        self.layer.shadowOffset = CGSize.zero
        self.layer.shadowRadius = 20
        self.layer.shouldRasterize = true
        self.layer.masksToBounds = false
    }
    func daysItemShadow() {
        self.layer.shadowColor = #colorLiteral(red: 0.2509803922, green: 0.2509803922, blue: 0.2509803922, alpha: 1).withAlphaComponent(0.1).cgColor
        self.layer.shadowOpacity = 1
        self.layer.shadowOffset = CGSize.zero
        self.layer.shadowRadius = 10
        self.layer.shouldRasterize = true
        self.layer.masksToBounds = false
    }
}
