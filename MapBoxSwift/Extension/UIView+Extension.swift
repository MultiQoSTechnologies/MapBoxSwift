//
//  UIView+Extension.swift
//  MaxBoxDemo
//
//  Created by MQF-6 on 21/06/24.
//

import UIKit

extension UIView {
    func setShadow(color: UIColor = UIColor.black, offset: CGSize = CGSize(width: 0, height: 6), radius: CGFloat = 6) {
        layer.shadowColor = color.cgColor
        layer.shadowOffset = offset
        layer.shadowRadius = radius
    }
    
    func setCorner(radius: CGFloat = 12) {
        layer.cornerRadius = radius
    }
    
    func showLoader() {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black.withAlphaComponent(0.3)
        view.accessibilityLabel = "loader_bg"
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.startAnimating()
        activityIndicator.center = self.center
        self.addSubview(view)
        view.addSubview(activityIndicator)
    }
    
    func hideLoader() {
        let _ = self.subviews.filter {$0.accessibilityLabel == "loader_bg"}.map{$0.removeFromSuperview()}
    }
}
