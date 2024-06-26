//
//  LocationHelper.swift
//  DeliveryApp
//
//  Created by MQF-6 on 06/02/24.
//

import Foundation
import CoreLocation

class LocationHelper: NSObject {
    static let shared = LocationHelper()
    
    private var manager: CLLocationManager!
     
    @Published var lastLocation: CLLocation?
    @Published var addressString: String?
    
    func requestLocation() {
        manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 50
        if #available(iOS 14.0, *) {
            self.check(status: manager.authorizationStatus)
        } else {
            self.check(status: CLLocationManager.authorizationStatus())
        }
        manager.delegate = self
        startMonitoring()
    }
    
    func startMonitoring() {
        manager.startUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
    }
    
    func stopMornitoring() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
    }
    
    func getAddressFrom(lat: Double, lon: Double) {
        var center : CLLocationCoordinate2D = CLLocationCoordinate2D()
        let ceo: CLGeocoder = CLGeocoder()
        center.latitude = lat
        center.longitude = lon
        
        let loc: CLLocation = CLLocation(latitude:center.latitude, longitude: center.longitude)
        
        ceo.reverseGeocodeLocation(loc, completionHandler:
                                    {(placemarks, error) in
            if (error != nil) {
                print("reverse geodcode fail: \(error!.localizedDescription)")
            }
            let pm = placemarks! as [CLPlacemark]
            
            if pm.count > 0 {
                let pm = placemarks![0]
                var addressString : String = ""
                if pm.subLocality != nil {
                    addressString = addressString + pm.subLocality! + ", "
                }
                if pm.thoroughfare != nil {
                    addressString = addressString + pm.thoroughfare! + ", "
                }
                if pm.locality != nil {
                    addressString = addressString + pm.locality! + ", "
                }
                if pm.country != nil {
                    addressString = addressString + pm.country! + ", "
                }
                if pm.postalCode != nil {
                    addressString = addressString + pm.postalCode! + " "
                }
                 
                self.addressString = addressString
            }
        })
    }
    
    private func check(status: CLAuthorizationStatus?) {
        guard let status = status else { return }
        switch status {
            
        case .authorizedWhenInUse,.authorizedAlways:
            self.manager.startUpdatingLocation()
            
        case .denied:
            print("Location permission denied enable from settings")
            
        case .restricted:
            print("Location permission restricted enable from settings")
            
        case .notDetermined:
            self.manager.requestWhenInUseAuthorization()
            
        @unknown default:
            print("Unknown")
        }
    }
}


extension LocationHelper: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        check(status: status)
    }
}
